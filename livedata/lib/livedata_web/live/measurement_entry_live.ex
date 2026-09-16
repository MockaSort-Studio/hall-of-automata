defmodule LivedataWeb.MeasurementEntryLive do
  @moduledoc """
  Manual raw-measurement entry (@req: KR 2.2, UC-2).

  Two things shape this form. First, provenance is captured as typed fields
  rather than hand-written JSON, so complete provenance is structural rather
  than hopeful (@req: CRCF-16). Second, a field campaign is many readings at
  one site: on success the activity, method, coordinates and CRS stay put and
  only the reading itself resets, so the next entry is a few keystrokes.
  """
  use LivedataWeb, :live_view

  alias Livedata.Measurements
  alias Livedata.Measurements.Entry
  alias Livedata.Projects
  alias LivedataWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New measurement")
     |> assign(:activity_options, activity_options())
     |> assign(:activity, nil)
     |> assign(:raw_json?, false)
     |> assign(:value_pairs, [%{"key" => "", "value" => ""}])
     |> assign_form(Entry.changeset(%Entry{}, defaults()))
     |> stream(:recorded, [])}
  end

  # An `activity_id` in the query string scopes the form to one activity, so
  # the dashboard and the activity page can hand over a form that already
  # points at the right place.
  @impl true
  def handle_params(params, _uri, socket) do
    activity_id = params["activity_id"]

    socket =
      case activity_id && Projects.get_activity_with_context!(activity_id) do
        nil ->
          assign(socket, :activity, nil)

        activity ->
          socket
          |> assign(:activity, activity)
          |> assign(:coverage, Measurements.coverage_for_activity(activity.id))
          |> assign_form(
            Entry.changeset(%Entry{}, Map.put(defaults(), "activity_id", activity.id))
          )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"measurement" => params}, socket) do
    params = put_values_json(params, socket.assigns.raw_json?)
    changeset = %Entry{} |> Entry.changeset(params) |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:value_pairs, value_pairs(params, socket.assigns.value_pairs))
     |> assign_form(changeset)}
  end

  def handle_event("save", %{"measurement" => params}, socket) do
    params = put_values_json(params, socket.assigns.raw_json?)

    case Measurements.create_raw_measurement(params) do
      {:ok, measurement} ->
        {:noreply,
         socket
         |> put_flash(:info, "Measurement recorded.")
         |> assign(:value_pairs, [%{"key" => "", "value" => ""}])
         |> assign_form(Entry.changeset(%Entry{}, next_entry_params(params)))
         |> stream_insert(:recorded, measurement, at: 0)}

      # @req: CRCF-28 — say what is duplicated, and what is not part of the check.
      {:error, :duplicate} ->
        changeset =
          %Entry{}
          |> Entry.changeset(params)
          |> Map.put(:action, :validate)
          |> Ecto.Changeset.add_error(
            :values_json,
            "an identical reading for this activity at this time already exists — " <>
              "provenance is not part of the duplicate check, so changing the " <>
              "coordinates will not make it a new reading"
          )

        {:noreply, assign_form(socket, changeset)}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("add_value", _params, socket) do
    {:noreply,
     assign(socket, :value_pairs, socket.assigns.value_pairs ++ [%{"key" => "", "value" => ""}])}
  end

  def handle_event("remove_value", %{"index" => index}, socket) do
    index = String.to_integer(index)
    pairs = List.delete_at(socket.assigns.value_pairs, index)

    {:noreply,
     assign(
       socket,
       :value_pairs,
       if(pairs == [], do: [%{"key" => "", "value" => ""}], else: pairs)
     )}
  end

  def handle_event("toggle_raw_json", _params, socket) do
    {:noreply, assign(socket, :raw_json?, not socket.assigns.raw_json?)}
  end

  # The browser reports coordinates far more reliably than a developer types them.
  def handle_event("set_coordinates", %{"latitude" => lat, "longitude" => lon}, socket) do
    params =
      socket.assigns.form.params
      |> Map.put("latitude", to_string(lat))
      |> Map.put("longitude", to_string(lon))

    {:noreply, assign_form(socket, Entry.changeset(%Entry{}, params))}
  end

  defp defaults do
    %{
      "measured_at" => DateTime.utc_now() |> DateTime.truncate(:second),
      "crs" => Entry.default_crs()
    }
  end

  # After a successful save, keep what identifies the site and drop what
  # identifies the reading. (UC-2)
  defp next_entry_params(params) do
    params
    |> Map.take(["activity_id", "method", "latitude", "longitude", "crs"])
    |> Map.put("measured_at", DateTime.utc_now() |> DateTime.truncate(:second))
  end

  # The repeater is the default editor; the raw textarea is for power users.
  # Either way what reaches the context is a single `values_json` string, so
  # #62 can swap the editor without touching the storage path.
  defp put_values_json(params, true), do: params

  defp put_values_json(params, false) do
    values =
      params
      |> value_rows()
      |> Enum.reject(fn %{"key" => key} -> String.trim(key) == "" end)
      |> Map.new(fn %{"key" => key, "value" => value} ->
        {String.trim(key), cast_value(value)}
      end)

    Map.put(params, "values_json", Jason.encode!(values))
  end

  # Numbers stay numbers so `content_hash` and any downstream computation see
  # a number, not a string.
  defp cast_value(value) do
    trimmed = String.trim(value)

    case Float.parse(trimmed) do
      {number, ""} -> number
      _other -> trimmed
    end
  end

  defp value_rows(params) do
    params
    |> Map.get("values", %{})
    |> Enum.sort_by(fn {index, _row} -> String.to_integer(index) end)
    |> Enum.map(fn {_index, row} ->
      %{"key" => row["key"] || "", "value" => row["value"] || ""}
    end)
  end

  defp value_pairs(params, fallback) do
    case value_rows(params) do
      [] -> fallback
      rows -> rows
    end
  end

  defp activity_options do
    Enum.map(Projects.list_activities(), fn a -> {"#{a.project_name} — #{a.name}", a.id} end)
  end

  defp assign_form(socket, changeset),
    do: assign(socket, :form, to_form(changeset, as: :measurement))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <:breadcrumbs>
        <Layouts.crumb navigate={~p"/"}>Dashboard</Layouts.crumb>
        <Layouts.crumb :if={@activity} navigate={~p"/projects/#{@activity.project_id}"}>
          {@activity.project_name}
        </Layouts.crumb>
        <Layouts.crumb :if={@activity} navigate={~p"/activities/#{@activity.id}"}>
          {@activity.name}
        </Layouts.crumb>
        <Layouts.crumb>Record measurement</Layouts.crumb>
      </:breadcrumbs>

      <h1 id="measurement-entry-title" class="text-2xl font-semibold">Record a measurement</h1>

      <div
        :if={@activity}
        id="entry-context"
        class="mb-2 rounded-lg border border-zinc-200 bg-zinc-50 p-4"
      >
        <p class="font-medium">{@activity.project_name} — {@activity.name}</p>
        <div class="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs">
          <span class="rounded-full bg-white px-2 py-0.5 font-medium text-zinc-600">
            {Format.activity_type(@activity.activity_type)}
          </span>
          <span
            :for={methodology <- @activity.methodologies}
            class="rounded-full border border-zinc-300 px-2 py-0.5 font-medium text-zinc-600"
          >
            {methodology}
          </span>
        </div>
        <p class="mt-2 text-sm text-base-content/60">
          Last measurement {Format.relative_time(@coverage.last_measured_at)} · {@coverage.count} on record
        </p>
      </div>

      <.form
        for={@form}
        id="measurement-entry-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <section :if={is_nil(@activity)} class="space-y-3">
          <.input
            field={@form[:activity_id]}
            type="select"
            label="Activity"
            prompt="Choose an activity"
            options={@activity_options}
          />
        </section>
        <input :if={@activity} type="hidden" name="measurement[activity_id]" value={@activity.id} />

        <.input field={@form[:measured_at]} type="datetime-local" label="Measured at (UTC)" />

        <section class="space-y-3">
          <h2 class="text-lg font-medium">Provenance</h2>
          <p class="text-sm text-base-content/60">
            Method, coordinates and projection are required on every record.
          </p>

          <.input field={@form[:method]} type="text" label="Method" />

          <div id="coordinates" class="grid gap-3 sm:grid-cols-3">
            <.input field={@form[:latitude]} type="number" step="any" label="Latitude" />
            <.input field={@form[:longitude]} type="number" step="any" label="Longitude" />
            <.input
              field={@form[:crs]}
              type="select"
              label="Coordinate reference system"
              options={Entry.crs_options()}
            />
          </div>

          <button
            type="button"
            id="use-my-location"
            phx-hook=".Geolocate"
            class="rounded-md border border-zinc-300 px-3 py-1.5 text-sm font-semibold transition-colors hover:bg-zinc-100"
          >
            Use my current location
          </button>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".Geolocate">
            export default {
              mounted() {
                this.el.addEventListener("click", () => {
                  if (!navigator.geolocation) { return }
                  navigator.geolocation.getCurrentPosition((position) => {
                    this.pushEvent("set_coordinates", {
                      latitude: position.coords.latitude,
                      longitude: position.coords.longitude,
                    })
                  })
                })
              }
            }
          </script>

          <.input
            field={@form[:extra_provenance_json]}
            type="textarea"
            label="Additional provenance (JSON, optional)"
          />
        </section>

        <section class="space-y-3">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-medium">Values</h2>
            <button
              type="button"
              id="toggle-raw-json"
              phx-click="toggle_raw_json"
              class="text-sm font-medium hover:underline"
            >
              {if @raw_json?, do: "Use fields", else: "Edit as JSON"}
            </button>
          </div>

          <div :if={not @raw_json?} id="values-repeater" class="space-y-2">
            <div :for={{pair, index} <- Enum.with_index(@value_pairs)} class="flex items-end gap-2">
              <label class="flex-1 text-sm">
                <span class="mb-1 block text-base-content/60">Name</span>
                <input
                  type="text"
                  name={"measurement[values][#{index}][key]"}
                  value={pair["key"]}
                  class="w-full input"
                />
              </label>
              <label class="flex-1 text-sm">
                <span class="mb-1 block text-base-content/60">Value</span>
                <input
                  type="text"
                  name={"measurement[values][#{index}][value]"}
                  value={pair["value"]}
                  class="w-full input"
                />
              </label>
              <button
                type="button"
                id={"remove-value-#{index}"}
                phx-click="remove_value"
                phx-value-index={index}
                class="mb-1 rounded-md border border-zinc-300 px-3 py-1.5 text-sm transition-colors hover:bg-zinc-100"
              >
                Remove
              </button>
            </div>

            <button
              type="button"
              id="add-value"
              phx-click="add_value"
              class="rounded-md border border-zinc-300 px-3 py-1.5 text-sm font-semibold transition-colors hover:bg-zinc-100"
            >
              Add value
            </button>

            <%!-- The repeater writes into this field, so errors on the payload
                  surface here whichever editor produced it. --%>
            <.input field={@form[:values_json]} type="hidden" />
            <p
              :for={message <- values_errors(@form)}
              id="values-error"
              class="mt-1.5 flex items-center gap-2 text-sm text-error"
            >
              <.icon name="hero-exclamation-circle" class="size-5" />
              {message}
            </p>
          </div>

          <.input
            :if={@raw_json?}
            field={@form[:values_json]}
            type="textarea"
            label="Values (JSON object)"
          />
        </section>

        <button
          type="submit"
          phx-disable-with="Saving…"
          class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-zinc-700"
        >
          Record measurement
        </button>
      </.form>

      <section class="space-y-2">
        <h2 class="text-lg font-medium">Recorded in this session</h2>
        <ul
          id="session-recorded"
          phx-update="stream"
          class="divide-y divide-zinc-200 rounded-lg border border-zinc-200"
        >
          <li
            id="session-recorded-empty"
            class="hidden px-4 py-6 text-center text-sm text-base-content/60 only:block"
          >
            Nothing recorded yet in this session.
          </li>
          <li :for={{dom_id, m} <- @streams.recorded} id={dom_id} class="px-4 py-3 text-sm">
            <div class="flex flex-wrap justify-between gap-2">
              <span class="font-medium">{Format.values_summary(m.values)}</span>
              <span class="text-base-content/60">{Format.utc(m.measured_at)}</span>
            </div>
            <p class="mt-0.5 font-mono text-xs text-base-content/50">{m.id}</p>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end

  # `values_json` is a hidden field when the repeater is in use, and
  # `used_input?/1` reports hidden fields as untouched, so its errors have to
  # be rendered explicitly. (@req: CRCF-38)
  defp values_errors(form) do
    if form.action do
      Enum.map(form[:values_json].errors, &translate_error/1)
    else
      []
    end
  end
end
