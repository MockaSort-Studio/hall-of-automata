defmodule LivedataWeb.ProjectShowLive do
  @moduledoc """
  A single project: the land it covers and the activities running on it.
  Measurements hang off activities, never off the project itself
  (@req: CRCF-21), so this page is a hub, not a data view — every measurement
  is one more click away, through its activity.
  """
  use LivedataWeb, :live_view

  alias Livedata.ProjectParcels
  alias Livedata.Projects
  alias LivedataWeb.Format

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project!(id)
    parcels = ProjectParcels.list_parcels_for_project(project.id)

    {:ok,
     socket
     |> assign(:page_title, project.name)
     |> assign(:project, project)
     |> assign(:parcels, parcels)
     |> assign(:activities, Projects.list_activities_with_stats(project_id: project.id))
     |> assign(:parcels_geojson, ProjectParcels.feature_collection(parcels))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-6xl">
      <:breadcrumbs>
        <Layouts.crumb navigate={~p"/"}>Dashboard</Layouts.crumb>
        <Layouts.crumb>{@project.name}</Layouts.crumb>
      </:breadcrumbs>

      <div id="project-detail" class="space-y-6">
        <header class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div class="flex items-center gap-2">
              <h1 class="text-2xl font-semibold">{@project.name}</h1>
              <span class="rounded-full bg-zinc-100 px-2 py-0.5 text-xs font-medium text-zinc-600">
                {@project.status}
              </span>
            </div>
            <p :if={@project.description} class="mt-1 text-base-content/70">
              {@project.description}
            </p>
            <p class="mt-1 text-sm text-base-content/60">
              Commissioned {Format.utc(@project.commissioned_at)}
            </p>
            <%!-- The UUID is the audit handle for everything below it. (@req: CRCF-19) --%>
            <p id="project-uuid" class="mt-1 font-mono text-xs text-base-content/50">
              {@project.id}
            </p>
          </div>

          <.link
            id="add-activity-link"
            navigate={~p"/projects/#{@project.id}/activities/new"}
            class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-zinc-700"
          >
            Add activity
          </.link>
        </header>

        <section class="space-y-2">
          <h2 class="text-lg font-medium">Land</h2>
          <div class="grid gap-4 lg:grid-cols-2">
            <div
              id="project-map"
              phx-hook="ProjectsMap"
              phx-update="ignore"
              data-projects={@parcels_geojson}
              class="h-72 w-full rounded-lg border border-zinc-200"
            >
            </div>

            <div
              :if={@parcels == []}
              id="parcels-empty"
              class="rounded-lg border border-dashed border-zinc-300 p-6 text-center text-sm text-base-content/60"
            >
              No parcels recorded for this project.
            </div>

            <table :if={@parcels != []} id="parcels-table" class="w-full text-sm">
              <thead class="text-left text-base-content/60">
                <tr>
                  <th class="pb-2 font-medium">Parcel</th>
                  <th class="pb-2 font-medium">Source</th>
                  <th class="pb-2 font-medium">Recorded</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-200">
                <tr :for={parcel <- @parcels} id={"parcel-#{parcel.parcel_ref}"}>
                  <td class="py-2 font-medium">{parcel.parcel_ref}</td>
                  <td class="py-2 text-base-content/70">{parcel.data_source}</td>
                  <td class="py-2 text-base-content/70">{Format.utc(parcel.recorded_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="space-y-2">
          <h2 class="text-lg font-medium">Activities</h2>

          <div
            :if={@activities == []}
            id="activities-empty"
            class="rounded-lg border border-dashed border-zinc-300 p-6 text-center text-sm text-base-content/60"
          >
            No activities yet. Add one to start recording measurements against it.
          </div>

          <div :if={@activities != []} class="overflow-x-auto">
            <table id="activities-table" class="w-full text-sm">
              <thead class="text-left text-base-content/60">
                <tr>
                  <th class="pb-2 font-medium">Activity</th>
                  <th class="pb-2 font-medium">Type</th>
                  <th class="pb-2 font-medium">Tier</th>
                  <th class="pb-2 font-medium">Activity period</th>
                  <th class="pb-2 font-medium">Monitoring period</th>
                  <th class="pb-2 font-medium">Measurements</th>
                  <th class="pb-2 font-medium">Last measured</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-200">
                <tr :for={activity <- @activities} id={"activity-row-#{activity.id}"}>
                  <td class="py-2">
                    <.link
                      navigate={~p"/activities/#{activity.id}"}
                      class="font-medium hover:underline"
                    >
                      {activity.name}
                    </.link>
                  </td>
                  <td class="py-2 text-base-content/70">
                    {Format.activity_type(activity.activity_type)}
                  </td>
                  <td class="py-2 text-base-content/70">{activity.storage_duration_tier}</td>
                  <td class="py-2 text-base-content/70">
                    {Format.period(activity.activity_period_start, activity.activity_period_end)}
                  </td>
                  <td class="py-2 text-base-content/70">
                    {Format.period(
                      activity.monitoring_period_start,
                      activity.monitoring_period_end
                    )}
                  </td>
                  <td class="py-2 text-base-content/70">{activity.measurement_count}</td>
                  <td class="py-2 text-base-content/70">
                    {Format.relative_time(activity.last_measured_at)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
