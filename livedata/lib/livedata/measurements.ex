defmodule Livedata.Measurements do
  @moduledoc """
  Ingestion + querying of raw measurements. `create_raw_measurement/1` validates
  the manual-entry form, computes the dedup content hash, and inserts one
  append-only raw measurement. (@req: KR 2.2)

  ## PubSub — `"measurements:new"`
  Both write paths broadcast `{:measurement_created, %RawMeasurement{}}` on
  success. OKR 3 consumers call `subscribe/0` when connected, then
  `stream_insert` in the matching `handle_info` clause.
  """
  import Ecto.Query

  alias Livedata.Projects.{Activity, Project}
  alias Livedata.Repo
  alias Livedata.Measurements.{Entry, RawMeasurement}

  @manual_source "MANUAL_ENTRY"
  @pubsub_topic "measurements:new"

  @doc """
  The most recently measured raw measurements across the whole portfolio, newest
  first, each carrying the activity and project it belongs to (@req: CRCF-22).

  This is what the dashboard's live submissions feed reads. It is deliberately
  the same row shape a PubSub broadcast will carry, so real-time propagation
  (#66, KR 2.3) becomes a `stream_insert/4` rather than a rewrite.
  """
  @spec list_recent(pos_integer()) :: [map()]
  def list_recent(limit \\ 10) do
    from(rm in RawMeasurement,
      join: a in Activity,
      on: a.id == rm.activity_id,
      join: p in Project,
      on: p.id == a.project_id,
      order_by: [desc: rm.measured_at],
      limit: ^limit,
      select: %{
        id: rm.id,
        measured_at: rm.measured_at,
        source_type: rm.source_type,
        values: rm.values,
        is_superseded: rm.is_superseded,
        activity_id: a.id,
        activity_name: a.name,
        project_id: p.id,
        project_name: p.name
      }
    )
    |> Repo.all()
  end

  @doc "Subscribes the calling process to `\"measurements:new\"` broadcasts."
  def subscribe, do: Phoenix.PubSub.subscribe(Livedata.PubSub, @pubsub_topic)

  @doc "Broadcasts `{:measurement_created, rm}` on `\"measurements:new\"`. Single write path for all producers."
  def broadcast_measurement(%RawMeasurement{} = rm) do
    Phoenix.PubSub.broadcast(Livedata.PubSub, @pubsub_topic, {:measurement_created, rm})
  end

  @spec create_raw_measurement(map()) ::
          {:ok, %RawMeasurement{}} | {:error, Ecto.Changeset.t()} | {:error, :duplicate}
  def create_raw_measurement(attrs) do
    entry_changeset = Entry.changeset(%Entry{}, attrs)

    if entry_changeset.valid? do
      entry = Ecto.Changeset.apply_changes(entry_changeset)
      provenance = Entry.provenance(entry)
      values = Entry.values(entry)
      hash = content_hash(@manual_source, entry.activity_id, entry.measured_at, values)

      changeset =
        RawMeasurement.changeset(%RawMeasurement{}, entry.activity_id, %{
          measured_at: entry.measured_at,
          source_type: @manual_source,
          content_hash: hash,
          provenance: provenance,
          values: values
        })

      insert_dedup(changeset)
    else
      {:error, Map.put(entry_changeset, :action, :validate)}
    end
  end

  # @req: CRCF-28 — unique_constraint on content_hash now translates to a changeset
  # error correctly; surface it as {:error, :duplicate} to keep the public interface stable.
  defp insert_dedup(changeset) do
    case Repo.insert(changeset) do
      {:ok, rm} ->
        # @req: CRCF-21 — broadcast on success only; never on validation failure or duplicate.
        broadcast_measurement(rm)
        {:ok, rm}

      {:error, cs} ->
        if Keyword.has_key?(cs.errors, :content_hash),
          do: {:error, :duplicate},
          else: {:error, cs}
    end
  end

  @doc """
  Raw measurements for one activity, newest first.

  Options: `:source_type`, `:from`, `:to` (both `DateTime`), `:include_superseded`
  (default `true`), `:limit`, `:offset`. Superseded records are never deleted —
  they are retained for audit and can only be hidden (@req: CRCF-26).
  """
  @spec list_for_activity(binary(), keyword()) :: [%RawMeasurement{}]
  def list_for_activity(activity_id, opts \\ []) do
    activity_id
    |> activity_scope(opts)
    |> order_by([rm], desc: rm.measured_at)
    |> limit(^Keyword.get(opts, :limit, 25))
    |> offset(^Keyword.get(opts, :offset, 0))
    |> Repo.all()
  end

  @doc "Counts the raw measurements for one activity under the same filters."
  @spec count_for_activity(binary(), keyword()) :: non_neg_integer()
  def count_for_activity(activity_id, opts \\ []) do
    Repo.aggregate(activity_scope(activity_id, opts), :count)
  end

  @doc """
  Coverage of one activity: how many measurements, and the span they cover.
  """
  @spec coverage_for_activity(binary()) :: %{
          count: non_neg_integer(),
          first_measured_at: DateTime.t() | nil,
          last_measured_at: DateTime.t() | nil
        }
  def coverage_for_activity(activity_id) do
    from(rm in RawMeasurement,
      where: rm.activity_id == ^activity_id,
      select: %{
        count: count(rm.id),
        first_measured_at: min(rm.measured_at),
        last_measured_at: max(rm.measured_at)
      }
    )
    |> Repo.one()
  end

  defp activity_scope(activity_id, opts) do
    from(rm in RawMeasurement, where: rm.activity_id == ^activity_id)
    |> filter_source_type(opts[:source_type])
    |> filter_from(opts[:from])
    |> filter_to(opts[:to])
    |> filter_superseded(Keyword.get(opts, :include_superseded, true))
  end

  defp filter_source_type(query, blank) when blank in [nil, ""], do: query
  defp filter_source_type(query, type), do: where(query, [rm], rm.source_type == ^type)

  defp filter_from(query, nil), do: query
  defp filter_from(query, from), do: where(query, [rm], rm.measured_at >= ^from)

  defp filter_to(query, nil), do: query
  defp filter_to(query, to), do: where(query, [rm], rm.measured_at <= ^to)

  defp filter_superseded(query, true), do: query
  defp filter_superseded(query, false), do: where(query, [rm], rm.is_superseded == false)

  @doc """
  Counts raw measurements recorded on or after `since`, by measurement time.
  """
  @spec count_since(DateTime.t()) :: non_neg_integer()
  def count_since(since) do
    Repo.aggregate(from(rm in RawMeasurement, where: rm.measured_at >= ^since), :count)
  end

  @doc """
  SHA-256 over a canonical serialization of the measurement content. Excludes
  provenance by design. Key order in `values` does not affect the hash. (@req: CRCF-28)
  """
  @spec content_hash(String.t(), binary(), DateTime.t(), map()) :: String.t()
  def content_hash(source_type, activity_id, measured_at, values) do
    payload =
      Jason.encode!([
        source_type,
        activity_id,
        DateTime.to_iso8601(measured_at),
        canonical(values)
      ])

    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  # Recursively sorts map keys so semantically-equal payloads hash identically.
  # Each structural case is tagged ("m"/"l") so a map and a list can never
  # canonicalize to the same shape (type-injective).
  defp canonical(v) when is_map(v) do
    [
      "m",
      v
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map(fn {k, val} -> [to_string(k), canonical(val)] end)
    ]
  end

  defp canonical(v) when is_list(v), do: ["l", Enum.map(v, &canonical/1)]
  defp canonical(v), do: v
end
