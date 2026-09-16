defmodule LivedataWeb.MeasurementUploadLive do
  @moduledoc """
  Bulk CSV upload for raw measurements. (@req: KR 2.2 — mode 2 of 2)

  The developer selects an activity, uploads a CSV file, and receives either
  a success count or a per-row error list. All-or-nothing semantics: nothing
  is written if any row fails. (@req: CRCF-27, CRCF-28, CRCF-38)
  """
  use LivedataWeb, :live_view

  alias Livedata.Measurements.BulkImport
  alias Livedata.Projects

  @max_file_size 5_000_000

  # A rejected 5 MB file can hold tens of thousands of bad rows. Rendering them
  # all pushes megabytes of markup over the websocket for no added insight.
  @max_shown_errors 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Upload measurements")
     |> assign(:activity, nil)
     |> assign(:selected_activity_id, "")
     |> assign(:activity_options, activity_options())
     |> assign(:errors, [])
     |> assign(:result, nil)
     |> allow_upload(:csv_file,
       accept: ~w(.csv text/csv),
       max_entries: 1,
       max_file_size: @max_file_size
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["activity_id"] do
        nil -> assign(socket, :activity, nil)
        id -> assign(socket, :activity, Projects.get_activity_with_context!(id))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :selected_activity_id, Map.get(params, "activity_id", ""))}
  end

  def handle_event("upload", params, socket) do
    entries = socket.assigns.uploads.csv_file.entries

    cond do
      entries == [] ->
        {:noreply, fail(socket, "choose a CSV file to import")}

      # consume_uploaded_entries/3 raises for any entry that is not done?, which
      # would take the whole LiveView down. Say what is wrong instead.
      Enum.any?(entries, &rejected?(socket, &1)) ->
        {:noreply, fail(socket, "that file was rejected — choose another")}

      Enum.any?(entries, &(not &1.done?)) ->
        {:noreply, fail(socket, "the file is still uploading — try again in a moment")}

      true ->
        import_csv(socket, Map.get(params, "activity_id", ""))
    end
  end

  defp fail(socket, message) do
    socket
    |> clear_flash()
    |> assign(:errors, [%{row: nil, field: :file, message: message}])
    |> assign(:result, nil)
  end

  defp rejected?(socket, entry), do: upload_errors(socket.assigns.uploads.csv_file, entry) != []

  defp import_csv(socket, activity_id) do
    csv_text = read_upload(socket)

    case BulkImport.import_csv(activity_id, csv_text) do
      {:ok, rows} ->
        n = length(rows)
        suffix = if n == 1, do: "", else: "s"
        label = "#{n} measurement#{suffix}"

        {:noreply,
         socket
         |> assign(:errors, [])
         |> assign(:result, label)
         |> put_flash(:info, "#{label} imported.")}

      {:error, errors} when is_list(errors) ->
        {:noreply,
         socket
         |> clear_flash()
         |> assign(:errors, errors)
         |> assign(:result, nil)}

      {:error, reason} ->
        {:noreply,
         socket
         |> clear_flash()
         |> assign(:errors, [%{row: nil, field: :file, message: describe_error(reason)}])
         |> assign(:result, nil)}
    end
  end

  defp read_upload(socket) do
    socket
    |> consume_uploaded_entries(:csv_file, fn %{path: path}, _entry ->
      {:ok, File.read!(path)}
    end)
    |> List.first("")
  end

  defp describe_error(:empty_file), do: "The file is empty."

  defp describe_error(:invalid_header),
    do:
      "Missing required columns. Expected: measured_at, method, latitude, longitude, values_json."

  defp describe_error(:no_data_rows), do: "The file has no data rows."
  defp describe_error(_), do: "Could not process the file."

  defp activity_options do
    Enum.map(Projects.list_activities(), fn a -> {"#{a.project_name} — #{a.name}", a.id} end)
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:shown_errors, Enum.take(assigns.errors, @max_shown_errors))
      |> assign(:hidden_error_count, max(length(assigns.errors) - @max_shown_errors, 0))

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
        <Layouts.crumb>Upload measurements</Layouts.crumb>
      </:breadcrumbs>

      <h1 class="text-2xl font-semibold">Upload measurements</h1>
      <p class="mt-1 text-sm text-base-content/60">
        CSV format:
        <code phx-no-curly-interpolation>
          measured_at, method, latitude, longitude, crs, values_json
        </code>
      </p>

      <.form
        for={%{}}
        id="upload-form"
        phx-change="validate"
        phx-submit="upload"
        class="mt-6 space-y-6"
      >
        <section :if={is_nil(@activity)} class="space-y-2">
          <label class="block text-sm font-medium">Activity</label>
          <select name="activity_id" id="activity-select" class="select">
            <option value="">Choose an activity</option>
            <option
              :for={{label, id} <- @activity_options}
              value={id}
              selected={to_string(id) == @selected_activity_id}
            >
              {label}
            </option>
          </select>
        </section>
        <input :if={@activity} type="hidden" name="activity_id" value={@activity.id} />

        <section class="space-y-2">
          <label class="block text-sm font-medium">CSV file</label>
          <.live_file_input upload={@uploads.csv_file} class="block w-full text-sm" />
          <%= for entry <- @uploads.csv_file.entries do %>
            <p :for={err <- upload_errors(@uploads.csv_file, entry)} class="text-sm text-error">
              {upload_error_message(err)}
            </p>
          <% end %>
          <p :for={err <- upload_errors(@uploads.csv_file)} class="text-sm text-error">
            {upload_error_message(err)}
          </p>
        </section>

        <button
          type="submit"
          phx-disable-with="Importing…"
          class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-zinc-700"
        >
          Import file
        </button>
      </.form>

      <div
        :if={@result}
        id="upload-result"
        class="mt-6 rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-800"
      >
        {@result} imported successfully.
      </div>

      <div :if={@errors != []} id="upload-errors" class="mt-6 space-y-2">
        <p class="font-medium text-error">Import failed — fix the following errors and re-upload:</p>
        <ul class="space-y-1 text-sm">
          <li :for={err <- @shown_errors} class="text-error">
            <%= if err.row do %>
              Row {err.row}: <strong>{err.field}</strong> — {err.message}
            <% else %>
              <strong>{err.field}</strong> — {err.message}
            <% end %>
          </li>
        </ul>
        <p :if={@hidden_error_count > 0} id="upload-errors-truncated" class="text-sm text-error/70">
          …and {@hidden_error_count} more.
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp upload_error_message(:too_large),
    do: "File too large (max #{div(@max_file_size, 1_000_000)} MB)."

  defp upload_error_message(:not_accepted), do: "Only CSV files are accepted."
  defp upload_error_message(:too_many_files), do: "Upload one file at a time."
  defp upload_error_message(_), do: "Upload error."
end
