defmodule CertfyWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CertfyWeb, :html

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

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 border-b border-base-300 bg-base-100/90 backdrop-blur">
      <div class="navbar mx-auto w-full max-w-7xl gap-2 px-4 sm:px-6 lg:px-8">
        <div class="navbar-start gap-1">
          <div class="dropdown lg:hidden">
            <div tabindex="0" role="button" class="btn btn-ghost btn-circle" aria-label="Menu">
              <.icon name="hero-bars-3" class="size-5" />
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu z-50 mt-2 w-56 rounded-box bg-base-100 p-2 shadow-lg"
            >
              <li><.link navigate={~p"/events"}>Eventos</.link></li>
              <li :if={admin?(@current_scope)}>
                <.link navigate={~p"/users"}>Usuários</.link>
              </li>
            </ul>
          </div>

          <.link navigate={~p"/events"} class="flex items-center gap-2 px-1">
            <img src={~p"/images/logo.svg"} width="32" alt="Certfy" />
            <span class="text-lg font-bold tracking-tight">Certfy</span>
          </.link>
        </div>

        <div class="navbar-center hidden lg:flex">
          <ul class="menu menu-horizontal gap-1 px-1">
            <li><.link navigate={~p"/events"}>Eventos</.link></li>
            <li :if={admin?(@current_scope)}>
              <.link navigate={~p"/users"}>Usuários</.link>
            </li>
          </ul>
        </div>

        <div class="navbar-end gap-1">
          <.theme_toggle />

          <div :if={@current_scope} class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost gap-2 px-2">
              <div class="avatar avatar-placeholder">
                <div class="w-8 rounded-full bg-primary text-primary-content">
                  <span class="text-xs font-semibold">{initials(@current_scope.user)}</span>
                </div>
              </div>
              <span class="hidden max-w-32 truncate text-sm sm:inline">
                {@current_scope.user.name}
              </span>
              <.icon name="hero-chevron-down" class="size-4 opacity-60" />
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu z-50 mt-3 w-64 rounded-box bg-base-100 p-2 shadow-lg"
            >
              <li class="menu-title">
                <span class="block max-w-56 truncate text-xs font-normal text-base-content/60">
                  {@current_scope.user.email}
                </span>
                <span class={role_badge(@current_scope.user)}>{role_label(@current_scope.user)}</span>
              </li>
              <li>
                <.link navigate={~p"/users/settings"}>
                  <.icon name="hero-cog-6-tooth" class="size-4" /> Configurações
                </.link>
              </li>
              <li>
                <.link href={~p"/users/log-out"} method="delete">
                  <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sair
                </.link>
              </li>
            </ul>
          </div>

          <.link
            :if={is_nil(@current_scope)}
            navigate={~p"/users/log-in"}
            class="btn btn-primary btn-sm"
          >
            Entrar
          </.link>
        </div>
      </div>
    </header>

    <main class="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
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
        title="Não conseguimos conectar à internet"
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Tentando reconectar
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Algo deu errado!"
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Tentando reconectar
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
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-circle" aria-label="Tema">
        <.icon name="hero-sun" class="size-5" />
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu z-50 mt-3 w-44 rounded-box bg-base-100 p-2 shadow-lg"
      >
        <li>
          <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system">
            <.icon name="hero-computer-desktop" class="size-4" /> Sistema
          </button>
        </li>
        <li>
          <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light">
            <.icon name="hero-sun" class="size-4" /> Claro
          </button>
        </li>
        <li>
          <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark">
            <.icon name="hero-moon" class="size-4" /> Escuro
          </button>
        </li>
      </ul>
    </div>
    """
  end

  defp admin?(nil), do: false
  defp admin?(scope), do: Certfy.Accounts.Scope.admin?(scope)

  defp role_label(%{role: :ADMIN}), do: "Administrador"
  defp role_label(_user), do: "Usuário"

  defp role_badge(%{role: :ADMIN}), do: "badge badge-primary badge-sm"
  defp role_badge(_user), do: "badge badge-ghost badge-sm"

  defp initials(%{name: name, email: email}) do
    source = if is_binary(name) and String.trim(name) != "", do: name, else: email

    source
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
