defmodule LivedataWeb.ActivityNewLive do
  @moduledoc """
  Adds an activity to a project that is already commissioned. A project
  accumulates activities over its life (@req: CRCF-34); commissioning only
  creates the first one.
  """
  use LivedataWeb, :live_view

  alias Livedata.Projects
  alias Livedata.Projects.ActivityForm

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    project = Projects.get_project!(project_id)

    {:ok,
     socket
     |> assign(:page_title, "Add activity")
     |> assign(:project, project)
     |> assign(
       :methodology_options,
       Enum.map(Projects.list_methodologies(), &{&1.name, &1.id})
     )
     |> assign_form(ActivityForm.changeset(%ActivityForm{}, %{}))}
  end

  @impl true
  def handle_event("validate", %{"activity" => params}, socket) do
    changeset = %ActivityForm{} |> ActivityForm.changeset(params) |> Map.put(:action, :validate)
    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"activity" => params}, socket) do
    case Projects.create_activity(socket.assigns.project.id, params) do
      {:ok, %{activity: activity}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Activity “#{activity.name}” added.")
         |> push_navigate(to: ~p"/activities/#{activity.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset),
    do: assign(socket, :form, to_form(changeset, as: :activity))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <:breadcrumbs>
        <Layouts.crumb navigate={~p"/"}>Dashboard</Layouts.crumb>
        <Layouts.crumb navigate={~p"/projects/#{@project.id}"}>{@project.name}</Layouts.crumb>
        <Layouts.crumb>Add activity</Layouts.crumb>
      </:breadcrumbs>

      <h1 id="add-activity-title" class="mb-1 text-2xl font-semibold">Add an activity</h1>
      <p class="mb-6 text-base-content/70">
        to <span class="font-medium">{@project.name}</span>
      </p>

      <.form
        for={@form}
        id="add-activity-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-4"
      >
        <.activity_fields
          form={@form}
          methodology_options={@methodology_options}
          selected_type={@form[:activity_type].value}
        />

        <button
          type="submit"
          phx-disable-with="Adding…"
          class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-zinc-700"
        >
          Add activity
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
