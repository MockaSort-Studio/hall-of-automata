defmodule LivedataWeb.ProjectRegistrationLive do
  # @req: KR 2.1
  use LivedataWeb, :live_view

  alias Livedata.Registration
  alias Livedata.Registration.Form

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Register project")
     |> assign(
       :methodology_options,
       Enum.map(Livedata.Projects.list_methodologies(), &{&1.name, &1.id})
     )
     |> assign_form(Form.changeset(%Form{}, %{}))}
  end

  @impl true
  def handle_event("validate", %{"registration" => params}, socket) do
    changeset = %Form{} |> Form.changeset(params) |> Map.put(:action, :validate)
    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("register", %{"registration" => params}, socket) do
    case Registration.register(params) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project registered.")
         |> push_navigate(to: ~p"/")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset),
    do: assign(socket, :form, to_form(changeset, as: :registration))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <h1 id="registration-title" class="text-2xl font-semibold mb-6">Register a project</h1>

      <.form
        for={@form}
        id="project-registration-form"
        phx-change="validate"
        phx-submit="register"
        class="space-y-8"
      >
        <section class="space-y-3">
          <h2 class="text-lg font-medium border-b border-zinc-200 pb-1">Project</h2>
          <.input field={@form[:project_name]} type="text" label="Project name" />
          <.input field={@form[:project_description]} type="textarea" label="Description" />
        </section>

        <section class="space-y-3">
          <h2 class="text-lg font-medium border-b border-zinc-200 pb-1">Parcel</h2>
          <.input field={@form[:parcel_ref]} type="text" label="Parcel reference" />
          <.input
            field={@form[:parcel_data_source]}
            type="select"
            label="Data source"
            prompt="Choose a source"
            options={["LPIS", "CADASTER"]}
          />
          <.input
            field={@form[:parcel_boundary_geojson]}
            type="textarea"
            label="Parcel boundary (GeoJSON MultiPolygon)"
          />
        </section>

        <section class="space-y-3">
          <h2 class="text-lg font-medium border-b border-zinc-200 pb-1">Activity</h2>
          <.activity_fields
            form={@form}
            methodology_options={@methodology_options}
            selected_type={@form[:activity_type].value}
          />
        </section>

        <button
          type="submit"
          phx-disable-with="Registering…"
          class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
        >
          Register project
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
