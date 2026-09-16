defmodule LivedataWeb.ActivityShowLive do
  @moduledoc """
  The activity workbench: the regulatory clock on one side, the evidence
  collected against it on the other.

  Measurements are the leaves of the hierarchy (@req: CRCF-21) and this is
  where they are read. Every row can be expanded to its full provenance,
  values and UUID, because that is what an audit asks for
  (@req: CRCF-19, CRCF-22).
  """
  use LivedataWeb, :live_view

  alias Livedata.Measurements
  alias Livedata.Projects
  alias LivedataWeb.Format

  @page_size 25
  @source_types ~w(MANUAL_ENTRY REMOTE_SENSING MODEL_OUTPUT)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    activity = Projects.get_activity_with_context!(id)

    {:ok,
     socket
     |> assign(:page_title, activity.name)
     |> assign(:activity, activity)
     |> assign(:source_types, @source_types)
     |> assign(:filters, %{
       "source_type" => "",
       "from" => "",
       "to" => "",
       "include_superseded" => "true"
     })
     |> assign(:expanded, MapSet.new())
     |> assign(:coverage, Measurements.coverage_for_activity(activity.id))
     |> load_measurements(reset: true)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      "source_type" => params["source_type"] || "",
      "from" => params["from"] || "",
      "to" => params["to"] || "",
      "include_superseded" => params["include_superseded"] || "false"
    }

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:expanded, MapSet.new())
     |> load_measurements(reset: true)}
  end

  def handle_event("load_more", _params, socket) do
    {:noreply, load_measurements(socket, reset: false)}
  end

  # Expanding re-inserts the row so the stream picks up the toggle.
  def handle_event("toggle", %{"id" => id}, socket) do
    expanded = socket.assigns.expanded

    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    measurement = Enum.find(socket.assigns.loaded, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:expanded, expanded)
     |> stream_insert(:measurements, measurement)}
  end

  defp load_measurements(socket, reset: reset?) do
    offset = if reset?, do: 0, else: socket.assigns.loaded_count
    opts = Keyword.merge(query_opts(socket.assigns.filters), limit: @page_size, offset: offset)
    page = Measurements.list_for_activity(socket.assigns.activity.id, opts)

    total =
      Measurements.count_for_activity(
        socket.assigns.activity.id,
        query_opts(socket.assigns.filters)
      )

    loaded = if reset?, do: page, else: socket.assigns.loaded ++ page

    socket
    |> assign(:loaded, loaded)
    |> assign(:loaded_count, length(loaded))
    |> assign(:total, total)
    |> stream(:measurements, page, reset: reset?)
  end

  defp query_opts(filters) do
    [
      source_type: filters["source_type"],
      from: parse_date_start(filters["from"]),
      to: parse_date_end(filters["to"]),
      include_superseded: filters["include_superseded"] == "true"
    ]
  end

  defp parse_date_start(blank) when blank in [nil, ""], do: nil

  defp parse_date_start(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp parse_date_end(blank) when blank in [nil, ""], do: nil

  defp parse_date_end(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
      _ -> nil
    end
  end

  # Where "today" sits inside the monitoring window, as a percentage.
  # An open-ended window has no progress to show. (@req: CRCF-14)
  defp monitoring_progress(%{monitoring_period_start: nil}), do: nil
  defp monitoring_progress(%{monitoring_period_end: nil}), do: nil

  defp monitoring_progress(activity) do
    total = Date.diff(activity.monitoring_period_end, activity.monitoring_period_start)
    elapsed = Date.diff(Date.utc_today(), activity.monitoring_period_start)

    cond do
      total <= 0 -> nil
      elapsed < 0 -> %{percent: 0, elapsed: 0, total: total}
      elapsed > total -> %{percent: 100, elapsed: total, total: total}
      true -> %{percent: round(elapsed / total * 100), elapsed: elapsed, total: total}
    end
  end

  defp provenance_summary(%{provenance: nil}), do: "—"

  defp provenance_summary(%{provenance: provenance}) do
    method = provenance["method"] || "unknown method"
    lat = provenance["latitude"]
    lon = provenance["longitude"]

    if lat && lon, do: "#{method} @ #{lat}, #{lon}", else: method
  end

  defp pretty_json(nil), do: "null"
  defp pretty_json(term), do: Jason.encode!(term, pretty: true)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-6xl">
      <:breadcrumbs>
        <Layouts.crumb navigate={~p"/"}>Dashboard</Layouts.crumb>
        <Layouts.crumb navigate={~p"/projects/#{@activity.project_id}"}>
          {@activity.project_name}
        </Layouts.crumb>
        <Layouts.crumb>{@activity.name}</Layouts.crumb>
      </:breadcrumbs>

      <div id="activity-detail" class="space-y-6">
        <header class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 class="text-2xl font-semibold">{@activity.name}</h1>
            <div class="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs">
              <span class="rounded-full bg-zinc-100 px-2 py-0.5 font-medium text-zinc-600">
                {Format.activity_type(@activity.activity_type)}
              </span>
              <span class="rounded-full bg-zinc-100 px-2 py-0.5 font-medium text-zinc-600">
                tier {@activity.storage_duration_tier}
              </span>
              <span class="rounded-full bg-zinc-100 px-2 py-0.5 font-medium text-zinc-600">
                {@activity.status}
              </span>
              <span
                :for={methodology <- @activity.methodologies}
                class="rounded-full border border-zinc-300 px-2 py-0.5 font-medium text-zinc-600"
              >
                {methodology}
              </span>
            </div>
            <p :if={@activity.description} class="mt-2 text-base-content/70">
              {@activity.description}
            </p>
            <p id="activity-uuid" class="mt-1 font-mono text-xs text-base-content/50">
              {@activity.id}
            </p>
          </div>

          <div class="flex gap-2">
            <.link
              id="activity-record-link"
              navigate={~p"/measurements/new?activity_id=#{@activity.id}"}
              class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-zinc-700"
            >
              Record measurement
            </.link>
            <.link
              id="activity-upload-link"
              navigate={~p"/measurements/upload?activity_id=#{@activity.id}"}
              class="rounded-md border border-zinc-300 px-4 py-2 text-sm font-semibold transition-colors hover:bg-zinc-100"
            >
              Upload file
            </.link>
          </div>
        </header>

        <section id="monitoring-timeline" class="space-y-2 rounded-lg border border-zinc-200 p-4">
          <div class="flex flex-wrap justify-between gap-2 text-sm">
            <span class="font-medium">Monitoring period</span>
            <span class="text-base-content/70">
              {Format.period(@activity.monitoring_period_start, @activity.monitoring_period_end)}
            </span>
          </div>

          <% progress = monitoring_progress(@activity) %>

          <div :if={progress} class="space-y-1">
            <div class="h-2 w-full overflow-hidden rounded-full bg-zinc-200">
              <div class="h-full rounded-full bg-zinc-900" style={"width: #{progress.percent}%"}>
              </div>
            </div>
            <p id="monitoring-progress" class="text-sm text-base-content/60">
              {progress.elapsed} of {progress.total} days elapsed ({progress.percent}%)
            </p>
          </div>

          <p :if={is_nil(progress)} id="monitoring-open-ended" class="text-sm text-base-content/60">
            Open-ended — {Format.activity_type(@activity.activity_type)} has no monitoring end date.
          </p>

          <p class="text-sm text-base-content/60">
            Activity period {Format.period(
              @activity.activity_period_start,
              @activity.activity_period_end
            )}
          </p>
        </section>

        <dl id="activity-coverage" class="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <div class="rounded-lg border border-zinc-200 px-4 py-3">
            <dt class="text-sm text-base-content/60">Measurements</dt>
            <dd class="mt-1 text-2xl font-semibold">{@coverage.count}</dd>
          </div>
          <div class="rounded-lg border border-zinc-200 px-4 py-3">
            <dt class="text-sm text-base-content/60">First measured</dt>
            <dd class="mt-1 text-sm">{Format.utc(@coverage.first_measured_at)}</dd>
          </div>
          <div class="rounded-lg border border-zinc-200 px-4 py-3">
            <dt class="text-sm text-base-content/60">Last measured</dt>
            <dd class="mt-1 text-sm">
              {Format.relative_time(@coverage.last_measured_at)}
            </dd>
          </div>
        </dl>

        <section class="space-y-3">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <h2 class="text-lg font-medium">Measurements</h2>

            <form id="measurement-filters" phx-change="filter" class="flex items-end gap-3">
              <label class="text-sm">
                <span class="mb-1 block text-base-content/60">Source</span>
                <select name="source_type" class="select select-sm">
                  <option value="">All sources</option>
                  <option
                    :for={type <- @source_types}
                    value={type}
                    selected={@filters["source_type"] == type}
                  >
                    {type}
                  </option>
                </select>
              </label>
              <label class="text-sm">
                <span class="mb-1 block text-base-content/60">From</span>
                <input
                  type="date"
                  name="from"
                  id="filter-from"
                  value={@filters["from"]}
                  class="rounded-md border border-zinc-300 px-2 py-1 text-sm"
                />
              </label>
              <label class="text-sm">
                <span class="mb-1 block text-base-content/60">To</span>
                <input
                  type="date"
                  name="to"
                  id="filter-to"
                  value={@filters["to"]}
                  class="rounded-md border border-zinc-300 px-2 py-1 text-sm"
                />
              </label>
              <label class="flex items-center gap-2 pb-2 text-sm">
                <input type="hidden" name="include_superseded" value="false" />
                <input
                  type="checkbox"
                  name="include_superseded"
                  value="true"
                  checked={@filters["include_superseded"] == "true"}
                  class="checkbox checkbox-sm"
                /> Show superseded
              </label>
            </form>
          </div>

          <div class="overflow-x-auto rounded-lg border border-zinc-200">
            <table class="w-full text-sm">
              <thead class="text-left text-base-content/60">
                <tr class="border-b border-zinc-200">
                  <th class="px-4 py-2 font-medium">Measured at</th>
                  <th class="px-4 py-2 font-medium">Source</th>
                  <th class="px-4 py-2 font-medium">Values</th>
                  <th class="px-4 py-2 font-medium">Provenance</th>
                  <th class="px-4 py-2"></th>
                </tr>
              </thead>
              <tbody id="measurements-table" phx-update="stream" class="divide-y divide-zinc-200">
                <tr id="measurements-empty" class="hidden only:table-row">
                  <td colspan="5" class="px-4 py-6 text-center text-base-content/60">
                    No measurements match these filters.
                  </td>
                </tr>
                <tr :for={{dom_id, m} <- @streams.measurements} id={dom_id} class="align-top">
                  <td class="px-4 py-2 whitespace-nowrap">
                    {Format.utc(m.measured_at)}
                    <span
                      :if={m.is_superseded}
                      class="ml-1 rounded bg-amber-100 px-1.5 py-0.5 text-xs font-medium text-amber-800"
                    >
                      superseded
                    </span>
                  </td>
                  <td class="px-4 py-2">
                    <span class="rounded bg-zinc-100 px-1.5 py-0.5 text-xs font-medium text-zinc-600">
                      {m.source_type}
                    </span>
                  </td>
                  <td class="px-4 py-2 text-base-content/70">{Format.values_summary(m.values)}</td>
                  <td class="px-4 py-2 text-base-content/70">{provenance_summary(m)}</td>
                  <td class="px-4 py-2 text-right">
                    <button
                      type="button"
                      id={"toggle-#{m.id}"}
                      phx-click="toggle"
                      phx-value-id={m.id}
                      class="text-sm font-medium hover:underline"
                    >
                      {if MapSet.member?(@expanded, m.id), do: "Hide", else: "Details"}
                    </button>

                    <div
                      :if={MapSet.member?(@expanded, m.id)}
                      id={"measurement-detail-#{m.id}"}
                      class="mt-2 space-y-2 text-left"
                    >
                      <p class="font-mono text-xs text-base-content/50">{m.id}</p>
                      <div>
                        <p class="text-xs font-medium text-base-content/60">provenance</p>
                        <pre
                          phx-no-curly-interpolation
                          class="overflow-x-auto rounded bg-zinc-50 p-2 text-xs"
                        ><%= pretty_json(m.provenance) %></pre>
                      </div>
                      <div>
                        <p class="text-xs font-medium text-base-content/60">values</p>
                        <pre
                          phx-no-curly-interpolation
                          class="overflow-x-auto rounded bg-zinc-50 p-2 text-xs"
                        ><%= pretty_json(m.values) %></pre>
                      </div>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="flex items-center justify-between text-sm text-base-content/60">
            <span id="measurements-count">
              Showing {@loaded_count} of {@total}
            </span>
            <button
              :if={@loaded_count < @total}
              id="load-more"
              type="button"
              phx-click="load_more"
              class="rounded-md border border-zinc-300 px-3 py-1.5 font-semibold text-base-content transition-colors hover:bg-zinc-100"
            >
              Load more
            </button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
