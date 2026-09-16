defmodule LivedataWeb.AdminLive do
  @moduledoc """
  Admin control panel — accessible only to users in the Cognito "admins" group.

  @req: KR 4.1
  """
  use LivedataWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Admin")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <h1 class="text-2xl font-semibold">Admin</h1>
      <p class="mt-2 text-base-content/60">Administrative controls.</p>
    </Layouts.app>
    """
  end
end
