defmodule Livedata.Projects do
  @moduledoc """
  Context for project queries.

  ## PubSub topic convention

  Activity creation broadcasts on `"activities:new"`:

      message: {:activity_created, %Activity{}}

  OKR 3 consumers subscribe once to receive live activity additions:

      def mount(_params, _session, socket) do
        if connected?(socket), do: Projects.subscribe_activities()
        {:ok, stream(socket, :activities, Projects.list_activities_with_stats())}
      end

      def handle_info({:activity_created, activity}, socket) do
        {:noreply, stream_insert(socket, :activities, activity, at: 0)}
      end
  """
  import Ecto.Query

  alias Ecto.Multi
  alias Livedata.Measurements.RawMeasurement
  alias Livedata.ProjectParcels
  alias Livedata.Repo
  alias Livedata.Projects.Methodology
  alias Livedata.Projects.{Activity, ActivityForm, ActivityMethodology, Project}

  @activities_topic "activities:new"

  @doc "Subscribes the calling process to new-activity broadcasts."
  @spec subscribe_activities() :: :ok | {:error, term()}
  def subscribe_activities, do: Phoenix.PubSub.subscribe(Livedata.PubSub, @activities_topic)

  @doc """
  Lists projects, newest first. Auth is out of scope, so this returns all
  projects (single-operator world until operator auth lands).
  """
  @spec list_projects() :: [%Project{}]
  def list_projects do
    Repo.all(from p in Project, order_by: [desc: p.inserted_at])
  end

  @doc """
  Fetches a single project, raising if it does not exist.
  """
  @spec get_project!(binary()) :: %Project{}
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Lists projects with the roll-up a developer needs to triage their portfolio:
  how much land, how much work, and how recently evidence arrived. Newest
  project first, matching `list_projects/0`.
  """
  @spec list_projects_with_stats() :: [map()]
  def list_projects_with_stats do
    parcel_counts = ProjectParcels.count_by_project()
    rollup = activity_rollup_by_project()
    empty = %{activity_count: 0, measurement_count: 0, last_measured_at: nil}

    for project <- list_projects() do
      stats = Map.get(rollup, project.id, empty)

      %{
        id: project.id,
        name: project.name,
        description: project.description,
        status: project.status,
        commissioned_at: project.commissioned_at,
        parcel_count: Map.get(parcel_counts, project.id, 0),
        activity_count: stats.activity_count,
        measurement_count: stats.measurement_count,
        last_measured_at: stats.last_measured_at
      }
    end
  end

  # Activity and measurement counts per project in one pass. Measurements hang
  # off activities, never off projects (@req: CRCF-21), so the roll-up has to
  # travel through `activities`.
  defp activity_rollup_by_project do
    from(a in Activity,
      left_join: rm in RawMeasurement,
      on: rm.activity_id == a.id,
      group_by: a.project_id,
      select:
        {a.project_id,
         %{
           activity_count: count(a.id, :distinct),
           measurement_count: count(rm.id),
           last_measured_at: max(rm.measured_at)
         }}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Lists activities with their parent project and measurement coverage. This is
  the row shape the dashboard, the project page and the monitoring rules all
  read from. (@req: CRCF-21, CRCF-22)
  """
  @spec list_activities_with_stats(keyword()) :: [map()]
  def list_activities_with_stats(opts \\ []) do
    from(a in Activity,
      join: p in Project,
      on: p.id == a.project_id,
      left_join: rm in RawMeasurement,
      on: rm.activity_id == a.id,
      group_by: [a.id, p.id],
      order_by: [asc: p.name, asc: a.name],
      select: %{
        id: a.id,
        name: a.name,
        description: a.description,
        project_id: p.id,
        project_name: p.name,
        activity_type: a.activity_type,
        storage_duration_tier: a.storage_duration_tier,
        status: a.status,
        activity_period_start: a.activity_period_start,
        activity_period_end: a.activity_period_end,
        monitoring_period_start: a.monitoring_period_start,
        monitoring_period_end: a.monitoring_period_end,
        measurement_count: count(rm.id),
        last_measured_at: max(rm.measured_at)
      }
    )
    |> filter_by_project(opts[:project_id])
    |> Repo.all()
  end

  defp filter_by_project(query, nil), do: query
  defp filter_by_project(query, project_id), do: where(query, [a], a.project_id == ^project_id)

  @doc """
  Fetches one activity together with its project and the names of the
  methodologies applied to it. (@req: CRCF-22, CRCF-35)
  """
  @spec get_activity_with_context!(binary()) :: map()
  def get_activity_with_context!(id) do
    activity =
      from(a in Activity,
        join: p in Project,
        on: p.id == a.project_id,
        where: a.id == ^id,
        select: %{
          id: a.id,
          name: a.name,
          description: a.description,
          project_id: p.id,
          project_name: p.name,
          activity_type: a.activity_type,
          storage_duration_tier: a.storage_duration_tier,
          status: a.status,
          activity_period_start: a.activity_period_start,
          activity_period_end: a.activity_period_end,
          monitoring_period_start: a.monitoring_period_start,
          monitoring_period_end: a.monitoring_period_end,
          inserted_at: a.inserted_at
        }
      )
      |> Repo.one()

    case activity do
      nil -> raise Ecto.NoResultsError, queryable: Activity
      activity -> Map.put(activity, :methodologies, methodology_names(activity.id))
    end
  end

  defp methodology_names(activity_id) do
    from(am in ActivityMethodology,
      join: m in Methodology,
      on: m.id == am.methodology_id,
      where: am.activity_id == ^activity_id,
      order_by: [asc: m.name],
      select: m.name
    )
    |> Repo.all()
  end

  @doc """
  Adds an activity to an existing project, with its methodology links, in one
  transaction. A project has many activities over its life (@req: CRCF-34) —
  only the first is created at commissioning.

  Mirrors `Livedata.Registration.register/2`: the form changeset is returned on
  failure so the LiveView renders field-level errors against form field names
  (@req: CRCF-38).
  """
  @spec create_activity(binary(), map()) ::
          {:ok, %{activity: %Activity{}, methodologies: [%ActivityMethodology{}]}}
          | {:error, Ecto.Changeset.t()}
  def create_activity(project_id, attrs) do
    form_changeset = ActivityForm.changeset(%ActivityForm{}, attrs)

    if form_changeset.valid? do
      form = Ecto.Changeset.apply_changes(form_changeset)
      applied_at = DateTime.utc_now()

      Multi.new()
      # @req: CRCF-21, CRCF-34
      |> Multi.insert(:activity, fn _changes ->
        Activity.changeset(%Activity{}, project_id, %{
          name: form.activity_name,
          description: form.activity_description,
          activity_type: form.activity_type,
          status: "REGISTERED",
          activity_period_start: form.activity_period_start,
          activity_period_end: form.activity_period_end,
          monitoring_period_start: form.monitoring_period_start,
          monitoring_period_end: form.monitoring_period_end
        })
      end)
      # @req: CRCF-35
      |> Multi.run(:methodologies, fn repo, %{activity: activity} ->
        link_methodologies(repo, activity.id, form.methodology_ids || [], applied_at)
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{activity: activity, methodologies: methodologies}} ->
          # @req: CRCF-21 — broadcast on success only; never on a rolled-back transaction.
          Phoenix.PubSub.broadcast(
            Livedata.PubSub,
            @activities_topic,
            {:activity_created, activity}
          )

          {:ok, %{activity: activity, methodologies: methodologies}}

        {:error, _step, _db_changeset, _changes} ->
          {:error, Map.put(form_changeset, :action, :validate)}
      end
    else
      {:error, Map.put(form_changeset, :action, :validate)}
    end
  end

  defp link_methodologies(repo, activity_id, methodology_ids, applied_at) do
    links =
      Enum.map(methodology_ids, fn methodology_id ->
        %ActivityMethodology{}
        |> ActivityMethodology.changeset(activity_id, %{
          methodology_id: methodology_id,
          applied_at: applied_at
        })
        |> repo.insert()
      end)

    case Enum.find(links, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(links, fn {:ok, link} -> link end)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Lists methodologies, ordered by name.
  """
  @spec list_methodologies() :: [%Methodology{}]
  def list_methodologies do
    Methodology |> order_by(asc: :name) |> Repo.all()
  end

  @doc """
  Lists activities for use in selection UIs, joined with their project name.
  `Activity.project_id` is a plain field (not a `belongs_to`), so this joins
  rather than preloads.
  """
  @spec list_activities() :: [%{id: binary(), name: String.t(), project_name: String.t()}]
  def list_activities do
    from(a in Activity,
      join: p in Project,
      on: a.project_id == p.id,
      order_by: [asc: p.name, asc: a.name],
      select: %{id: a.id, name: a.name, project_name: p.name}
    )
    |> Repo.all()
  end
end
