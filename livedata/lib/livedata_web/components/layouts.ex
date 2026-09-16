defmodule LivedataWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LivedataWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :map, default: nil, doc: "authenticated user map or nil"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :max_width, :string,
    default: "max-w-2xl",
    doc: "content width — forms keep the narrow default, data-dense pages widen"

  slot :breadcrumbs, doc: "trail rendered above the page content"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header id="app-header" class="navbar gap-4 border-b border-base-300 px-4 sm:px-6 lg:px-8">
      <.link navigate={~p"/"} class="text-lg font-semibold tracking-tight">
        Air2Tree
      </.link>

      <nav :if={@current_user} id="app-nav" class="flex flex-1 items-center gap-1 text-sm">
        <.nav_link id="nav-dashboard" navigate={~p"/"}>Dashboard</.nav_link>
        <.nav_link id="nav-record" navigate={~p"/measurements/new"}>Record measurement</.nav_link>
        <.nav_link id="nav-register" navigate={~p"/projects/new"}>Register project</.nav_link>
      </nav>

      <div :if={!@current_user} class="flex-1" />

      <div :if={@current_user} id="app-user-menu" class="flex items-center gap-3 text-sm">
        <span class="hidden text-base-content/50 sm:block">{@current_user["email"]}</span>
        <.link
          id="nav-signout"
          href={~p"/auth"}
          method="delete"
          class="rounded-md px-3 py-1.5 text-base-content/70 transition-colors hover:bg-base-200 hover:text-base-content"
        >
          Sign out
        </.link>
      </div>

      <.theme_toggle />
    </header>

    <main class="px-4 py-10 sm:px-6 lg:px-8">
      <div class={["mx-auto space-y-4", @max_width]}>
        <nav :if={@breadcrumbs != []} id="breadcrumbs" class="text-sm text-base-content/60">
          {render_slot(@breadcrumbs)}
        </nav>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :id, :string, required: true
  attr :navigate, :string, required: true
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@navigate}
      class="rounded-md px-3 py-1.5 text-base-content/70 transition-colors hover:bg-base-200 hover:text-base-content"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  A single step in the breadcrumb trail. The last step is the current page and
  is rendered as plain text.

      <:breadcrumbs>
        <.crumb navigate={~p"/"}>Dashboard</.crumb>
        <.crumb>{@project.name}</.crumb>
      </:breadcrumbs>
  """
  attr :navigate, :string, default: nil
  slot :inner_block, required: true

  def crumb(assigns) do
    ~H"""
    <span class="after:mx-2 after:text-base-content/30 after:content-['/'] last:after:content-none">
      <.link :if={@navigate} navigate={@navigate} class="hover:underline">
        {render_slot(@inner_block)}
      </.link>
      <span :if={is_nil(@navigate)} class="text-base-content">{render_slot(@inner_block)}</span>
    </span>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
