defmodule LivedataWeb.DashboardLive do
  @moduledoc """
  The project developer's home. Answers "what do I owe?" before "what do I
  have?": monitoring obligations come first, the portfolio second, and the
  submission feed last. (@req: KR 2.1, KR 2.2, KR 2.3)
  """
  use LivedataWeb, :live_view

  alias Livedata.Measurements
  alias Livedata.Monitoring
  alias Livedata.ProjectParcels
  alias Livedata.Projects
  alias LivedataWeb.Format

  @recent_limit 10

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects_with_stats()
    attention = Monitoring.attention_items()
    parcels = ProjectParcels.list_parcels_with_project()

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:projects, projects)
     |> assign(:attention, attention)
     |> assign(:selected_project_id, nil)
     |> assign(:stats, stats(projects, attention))
     |> assign(:parcels_geojson, ProjectParcels.feature_collection(parcels))
     |> stream(:recent, Measurements.list_recent(@recent_limit))}
  end

  # Selecting a project on either side of the split highlights it on the other:
  # a click on a card pushes to the map hook, a click on a parcel comes back in.
  @impl true
  def handle_event("select_project", %{"project-id" => project_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_project_id, project_id)
     |> push_event("highlight_project", %{project_id: project_id})}
  end

  def handle_event("map_selected_project", %{"project_id" => project_id}, socket) do
    {:noreply, assign(socket, :selected_project_id, project_id)}
  end

  defp stats(projects, attention) do
    since = DateTime.add(DateTime.utc_now(), -30, :day)

    %{
      projects: length(projects),
      activities: Enum.sum(Enum.map(projects, & &1.activity_count)),
      recent_measurements: Measurements.count_since(since),
      attention: length(attention)
    }
  end

  defp attention_label(%{reason: :never_measured}), do: "never measured"
  defp attention_label(%{days_since_measurement: days}), do: "no data for #{days} days"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-6xl">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h1 class="text-2xl font-semibold">Your portfolio</h1>
        <div class="flex gap-2">
          <.link
            id="record-measurement-link"
            navigate={~p"/measurements/new"}
            class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-zinc-700"
          >
            Record measurement
          </.link>
          <.link
            id="register-project-link"
            navigate={~p"/projects/new"}
            class="rounded-md border border-zinc-300 px-4 py-2 text-sm font-semibold transition-colors hover:bg-zinc-100"
          >
            Register project
          </.link>
        </div>
      </div>

      <dl id="dashboard-stats" class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <.stat id="stat-projects" label="Projects" value={@stats.projects} />
        <.stat id="stat-activities" label="Activities" value={@stats.activities} />
        <.stat
          id="stat-measurements"
          label="Measurements (30 days)"
          value={@stats.recent_measurements}
        />
        <.stat id="stat-attention" label="Needs attention" value={@stats.attention} emphasise />
      </dl>

      <section class="space-y-2">
        <h2 class="text-lg font-medium">Needs attention</h2>
        <p class="text-sm text-base-content/60">
          Activities inside their monitoring window with no recent evidence.
          Threshold: {Monitoring.stale_after_days()} days — provisional until
          monitoring frequency comes from the methodology.
        </p>

        <div
          :if={@attention == []}
          id="attention-empty"
          class="rounded-lg border border-dashed border-zinc-300 p-6 text-center text-sm text-base-content/60"
        >
          All activities are up to date.
        </div>

        <ul
          :if={@attention != []}
          id="attention-list"
          class="divide-y divide-zinc-200 rounded-lg border border-zinc-200"
        >
          <li
            :for={item <- @attention}
            id={"attention-#{item.id}"}
            class="flex flex-wrap items-center justify-between gap-3 px-4 py-3"
          >
            <div class="min-w-0">
              <p class="truncate font-medium">
                {item.project_name} —
                <.link navigate={~p"/activities/#{item.id}"} class="hover:underline">
                  {item.name}
                </.link>
              </p>
              <p class="mt-0.5 text-sm text-base-content/60">
                <span class="font-medium text-amber-700">{attention_label(item)}</span>
                · {Format.activity_type(item.activity_type)} · monitoring {Format.period(
                  item.monitoring_period_start,
                  item.monitoring_period_end
                )}
              </p>
            </div>
            <.link
              id={"attention-record-#{item.id}"}
              navigate={~p"/measurements/new?activity_id=#{item.id}"}
              class="shrink-0 rounded-md border border-zinc-300 px-3 py-1.5 text-sm font-semibold transition-colors hover:bg-zinc-100"
            >
              Record
            </.link>
          </li>
        </ul>
      </section>

      <section class="grid gap-4 lg:grid-cols-2">
        <div class="space-y-2">
          <h2 class="text-lg font-medium">Projects</h2>

          <div
            :if={@projects == []}
            id="dashboard-empty"
            class="rounded-lg border border-dashed border-zinc-300 p-6 text-center text-sm text-base-content/60"
          >
            No projects yet. Register your first project to see it on the map.
          </div>

          <ul :if={@projects != []} id="projects-list" class="space-y-2">
            <li
              :for={project <- @projects}
              id={"project-card-#{project.id}"}
              phx-click="select_project"
              phx-value-project-id={project.id}
              class={[
                "cursor-pointer rounded-lg border p-4 transition-colors hover:border-zinc-400",
                if(@selected_project_id == project.id,
                  do: "border-zinc-900 bg-zinc-50",
                  else: "border-zinc-200"
                )
              ]}
            >
              <div class="flex items-start justify-between gap-3">
                <.link
                  id={"project-link-#{project.id}"}
                  navigate={~p"/projects/#{project.id}"}
                  class="font-medium hover:underline"
                >
                  {project.name}
                </.link>
                <span class="shrink-0 rounded-full bg-zinc-100 px-2 py-0.5 text-xs font-medium text-zinc-600">
                  {project.status}
                </span>
              </div>
              <p :if={project.description} class="mt-0.5 line-clamp-2 text-sm text-base-content/60">
                {project.description}
              </p>
              <p class="mt-2 text-sm text-base-content/60">
                {project.activity_count} activities · {project.parcel_count} parcels · {project.measurement_count} measurements · last {Format.relative_time(
                  project.last_measured_at
                )}
              </p>
            </li>
          </ul>
        </div>

        <div
          id="projects-map"
          phx-hook="ProjectsMap"
          phx-update="ignore"
          data-projects={@parcels_geojson}
          class="h-96 w-full rounded-lg border border-zinc-200 lg:h-full lg:min-h-96"
        >
        </div>
      </section>

      <section class="space-y-2">
        <h2 class="text-lg font-medium">Recent submissions</h2>
        <ul
          id="recent-measurements"
          phx-update="stream"
          class="divide-y divide-zinc-200 rounded-lg border border-zinc-200"
        >
          <li
            id="recent-empty"
            class="hidden px-4 py-6 text-center text-sm text-base-content/60 only:block"
          >
            Nothing submitted yet.
          </li>
          <li :for={{dom_id, m} <- @streams.recent} id={dom_id} class="px-4 py-3">
            <div class="flex flex-wrap items-baseline justify-between gap-2">
              <p class="font-medium">
                {m.project_name} —
                <.link navigate={~p"/activities/#{m.activity_id}"} class="hover:underline">
                  {m.activity_name}
                </.link>
              </p>
              <p class="text-sm text-base-content/60" title={Format.utc(m.measured_at)}>
                {Format.relative_time(m.measured_at)}
              </p>
            </div>
            <p class="mt-0.5 text-sm text-base-content/60">
              <span class="rounded bg-zinc-100 px-1.5 py-0.5 text-xs font-medium text-zinc-600">
                {m.source_type}
              </span>
              <span class="ml-1">{Format.values_summary(m.values)}</span>
            </p>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :emphasise, :boolean, default: false

  defp stat(assigns) do
    ~H"""
    <div id={@id} class="rounded-lg border border-zinc-200 px-4 py-3">
      <dt class="text-sm text-base-content/60">{@label}</dt>
      <dd class={[
        "mt-1 text-2xl font-semibold",
        @emphasise && @value > 0 && "text-amber-700"
      ]}>
        {@value}
      </dd>
    </div>
    """
  end
end
