defmodule Livedata.Measurements.BulkImport do
  @moduledoc """
  All-or-nothing bulk import of raw measurements from a parsed CSV.

  Validates every row through the Entry changeset, detects batch-internal
  duplicates by content_hash, then inserts all rows in a single Ecto.Multi
  transaction. A single invalid row or duplicate causes the whole batch to
  be rejected — no partial import. (@req: CRCF-27, CRCF-28, CRCF-38)
  """

  alias Ecto.Multi
  alias Livedata.Measurements
  alias Livedata.Measurements.{CsvParser, Entry, RawMeasurement}
  alias Livedata.Repo

  @manual_source "MANUAL_ENTRY"

  @type row_error :: %{row: pos_integer(), field: atom(), message: String.t()}

  @spec import_csv(binary(), String.t()) ::
          {:ok, [%RawMeasurement{}]}
          | {:error, [row_error()] | :invalid_header | :no_data_rows | :empty_file}
  def import_csv(activity_id, csv_text) do
    if blank_or_malformed_activity?(activity_id) do
      {:error, [%{row: nil, field: :activity_id, message: "choose an activity before importing"}]}
    else
      with {:ok, rows} <- CsvParser.parse(csv_text),
           {:ok, validated} <- validate_rows(rows, activity_id),
           :ok <- check_batch_duplicates(validated) do
        insert_all(validated)
      end
    end
  end

  # Entry's :binary_id cast only checks is_binary/1 on an embedded schema, so a
  # non-UUID passes row validation and raises Ecto.ChangeError at insert — which
  # the constraint rescue below does not catch. Reject the shape up front.
  defp blank_or_malformed_activity?(activity_id) when is_binary(activity_id),
    do: Ecto.UUID.cast(activity_id) == :error

  defp blank_or_malformed_activity?(_), do: true

  # ---------------------------------------------------------------------------
  # Row validation
  # ---------------------------------------------------------------------------

  defp validate_rows(rows, activity_id) do
    {changesets, errors} =
      rows
      |> Enum.map(&validate_row(&1, activity_id))
      |> Enum.split_with(fn {status, _} -> status == :ok end)

    if errors == [] do
      {:ok, Enum.map(changesets, fn {:ok, cs} -> cs end)}
    else
      {:error, Enum.flat_map(errors, fn {:error, errs} -> errs end)}
    end
  end

  defp validate_row(row, activity_id) do
    row_num = Map.get(row, "_row", 0)
    params = Map.merge(row, %{"activity_id" => activity_id})
    changeset = Entry.changeset(%Entry{}, params) |> Map.put(:action, :validate)

    if changeset.valid? do
      entry = Ecto.Changeset.apply_changes(changeset)
      values = Entry.values(entry)
      hash = Measurements.content_hash(@manual_source, activity_id, entry.measured_at, values)

      attrs = %{
        activity_id: activity_id,
        measured_at: entry.measured_at,
        source_type: @manual_source,
        content_hash: hash,
        provenance: Entry.provenance(entry),
        values: values,
        _row: row_num
      }

      {:ok, attrs}
    else
      errors =
        changeset.errors
        |> Enum.map(fn {field, {msg, opts}} ->
          %{row: row_num, field: field, message: translate_error({msg, opts})}
        end)

      {:error, errors}
    end
  end

  # ---------------------------------------------------------------------------
  # Batch-internal deduplication
  # ---------------------------------------------------------------------------

  defp check_batch_duplicates(validated) do
    hashes = Enum.map(validated, & &1.content_hash)
    unique_hashes = Enum.uniq(hashes)

    if length(hashes) == length(unique_hashes) do
      :ok
    else
      dup_hashes = hashes -- unique_hashes

      errors =
        validated
        |> Enum.filter(&(&1.content_hash in dup_hashes))
        |> Enum.map(&%{row: &1._row, field: :content_hash, message: "duplicate row in this file"})

      {:error, errors}
    end
  end

  # ---------------------------------------------------------------------------
  # Transaction insert
  # ---------------------------------------------------------------------------

  defp insert_all(validated) do
    multi =
      validated
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {attrs, idx}, multi ->
        Multi.run(multi, {:row, idx}, fn _repo, _changes ->
          insert_one(attrs)
        end)
      end)

    case Repo.transaction(multi) do
      {:ok, results} ->
        rows =
          results |> Enum.sort_by(fn {{:row, i}, _} -> i end) |> Enum.map(fn {_, rm} -> rm end)

        broadcast_all(rows)
        {:ok, rows}

      {:error, {:row, idx}, %Ecto.Changeset{} = cs, _changes} ->
        row_num = Enum.at(validated, idx)._row
        {field, msg} = changeset_to_error(cs)
        {:error, [%{row: row_num, field: field, message: msg}]}

      {:error, {:row, idx}, reason, _changes} when is_binary(reason) ->
        row_num = Enum.at(validated, idx)._row
        {:error, [%{row: row_num, field: :content_hash, message: reason}]}
    end
  end

  # @req: CRCF-28 — unique_constraint on content_hash now returns {:error, changeset};
  # convert to a binary reason so insert_all can surface a per-row user message.
  defp insert_one(attrs) do
    changeset =
      RawMeasurement.changeset(%RawMeasurement{}, attrs.activity_id, %{
        measured_at: attrs.measured_at,
        source_type: attrs.source_type,
        content_hash: attrs.content_hash,
        provenance: attrs.provenance,
        values: attrs.values
      })

    case Repo.insert(changeset) do
      {:ok, rm} ->
        {:ok, rm}

      {:error, cs} ->
        if Keyword.has_key?(cs.errors, :content_hash),
          do: {:error, "this measurement already exists in the database"},
          else: {:error, cs}
    end
  end

  defp broadcast_all(rows) do
    Enum.each(rows, &Measurements.broadcast_measurement/1)
  end

  defp changeset_to_error(%Ecto.Changeset{errors: [{field, {msg, opts}} | _]}),
    do: {field, translate_error({msg, opts})}

  defp changeset_to_error(_), do: {:base, "could not save measurement"}

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
