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

  attr :nav, :atom, default: nil, doc: "the active navigation section"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if @current_scope do %>
      <div id="app-shell" class="drawer min-h-screen lg:drawer-open" phx-hook="Drawer">
        <input id="app-drawer" type="checkbox" class="drawer-toggle" />

        <div class="drawer-content flex min-h-screen flex-col">
          <header
            id="app-topbar"
            class="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-base-300 bg-base-100/95 px-4 backdrop-blur sm:px-6"
            phx-hook="Dropdown"
          >
            <label for="app-drawer" class="btn btn-ghost btn-square lg:hidden" aria-label="Abrir menu">
              <.icon name="hero-bars-3" class="size-5" />
            </label>

            <div class="flex-1"></div>
            <.theme_toggle />
          </header>

          <main class="mx-auto w-full max-w-[1400px] px-4 py-6 sm:px-6 lg:px-8">
            {render_slot(@inner_block)}
          </main>
        </div>

        <div class="drawer-side z-40">
          <label for="app-drawer" aria-label="Fechar menu" class="drawer-overlay"></label>

          <aside class="flex min-h-full w-64 flex-col border-r border-base-300 bg-base-100">
            <.link
              navigate={~p"/"}
              class="flex h-16 items-center gap-2 border-b border-base-300 px-5"
              aria-label="Certfy — início"
            >
              <svg viewBox="0 0 32 32" class="h-8 w-8 text-primary" aria-hidden="true">
                <circle cx="16" cy="16" r="13" fill="none" stroke="currentColor" stroke-width="2.25" />
                <circle cx="16" cy="16" r="9" fill="none" stroke="currentColor" stroke-width="1" />
                <path
                  d="M20.4 12.6a5.2 5.2 0 0 0-4-1.7c-2.9 0-4.9 2.2-4.9 5.1s2 5.1 4.9 5.1c1.6 0 2.9-.6 3.9-1.7l-1.9-1.5c-.5.5-1.1.8-1.9.8-1.3 0-2.2-.9-2.2-2.7s.9-2.7 2.2-2.7c.8 0 1.4.3 1.9.8z"
                  fill="currentColor"
                />
              </svg>
              <span class="text-lg font-semibold tracking-tight">Certfy</span>
            </.link>

            <nav class="flex-1 overflow-y-auto p-3">
              <p class="px-3 pb-2 text-xs font-medium text-base-content/50">Gestão</p>
              <ul class="menu w-full gap-1 p-0">
                <li>
                  <.link
                    navigate={~p"/"}
                    class={[
                      "flex items-center gap-3 rounded-lg px-3 py-2.5",
                      nav_class(@nav, :home)
                    ]}
                  >
                    <.icon name="hero-home" class="size-5" /> Início
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/events"}
                    class={[
                      "flex items-center gap-3 rounded-lg px-3 py-2.5",
                      nav_class(@nav, :events)
                    ]}
                  >
                    <.icon name="hero-calendar-days" class="size-5" /> Eventos
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/participants"}
                    class={[
                      "flex items-center gap-3 rounded-lg px-3 py-2.5",
                      nav_class(@nav, :participants)
                    ]}
                  >
                    <.icon name="hero-users" class="size-5" /> Participantes
                  </.link>
                </li>
              </ul>

              <div class="mt-6">
                <p class="px-3 pb-2 text-xs font-medium text-base-content/50">Ajuda</p>
                <ul class="menu w-full gap-1 p-0">
                  <li>
                    <.link
                      navigate={~p"/como-funciona"}
                      class={[
                        "flex items-center gap-3 rounded-lg px-3 py-2.5",
                        nav_class(@nav, :help)
                      ]}
                    >
                      <.icon name="hero-question-mark-circle" class="size-5" /> Como funciona
                    </.link>
                  </li>
                </ul>
              </div>

              <div :if={admin?(@current_scope)} class="mt-6">
                <p class="px-3 pb-2 text-xs font-medium text-base-content/50">Administração</p>
                <ul class="menu w-full gap-1 p-0">
                  <li>
                    <.link
                      navigate={~p"/users"}
                      class={[
                        "flex items-center gap-3 rounded-lg px-3 py-2.5",
                        nav_class(@nav, :users)
                      ]}
                    >
                      <.icon name="hero-user-group" class="size-5" /> Usuários
                    </.link>
                  </li>
                </ul>
              </div>
            </nav>

            <div class="border-t border-base-300 p-3">
              <div class="dropdown dropdown-top w-full">
                <div tabindex="0" role="button" class="btn btn-ghost w-full justify-start gap-3 px-2">
                  <div class="avatar avatar-placeholder">
                    <div class="w-9 rounded-full bg-primary text-primary-content">
                      <span class="text-xs font-semibold">{initials(@current_scope.user)}</span>
                    </div>
                  </div>
                  <div class="min-w-0 flex-1 text-left">
                    <p class="truncate text-sm font-medium">{@current_scope.user.name}</p>
                    <p class="truncate text-xs text-base-content/60">
                      {role_label(@current_scope.user)}
                    </p>
                  </div>
                  <.icon name="hero-chevron-up" class="size-4 opacity-60" />
                </div>

                <ul
                  tabindex="0"
                  class="dropdown-content menu z-50 mb-2 w-60 rounded-box border border-base-300 bg-base-100 p-2 shadow-lg"
                >
                  <li class="menu-title">
                    <span class="block max-w-52 truncate text-sm font-normal text-base-content/70">
                      {@current_scope.user.email}
                    </span>
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
            </div>
          </aside>
        </div>
      </div>
    <% else %>
      <main class="min-h-screen px-4 py-10">
        {render_slot(@inner_block)}
      </main>
    <% end %>

    <dialog id="confirm-dialog" class="modal" phx-hook="ConfirmDialog">
      <div class="modal-box border border-base-300 shadow-xl">
        <h3 class="text-lg font-semibold">Confirmar ação</h3>

        <p data-confirm-message class="py-4 text-base"></p>

        <div class="modal-action">
          <button type="button" data-confirm-cancel class="btn btn-ghost">
            Cancelar
          </button>

          <button type="button" data-confirm-ok class="btn btn-primary">
            Confirmar
          </button>
        </div>
      </div>
    </dialog>
    <.flash_group flash={@flash} />
    """
  end

  defp nav_class(nav, section) do
    if nav == section do
      "bg-primary/10 font-medium text-primary"
    else
      "hover:bg-base-200"
    end
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
      <.flash kind={:info} flash={@flash} /> <.flash kind={:error} flash={@flash} />
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
        class="dropdown-content menu z-50 mt-3 w-44 rounded-box border border-base-300 bg-base-100 p-2 shadow-lg"
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

  defp admin?(scope), do: Certfy.Accounts.Scope.admin?(scope)

  defp role_label(%{role: :ADMIN}), do: "Administrador"
  defp role_label(_user), do: "Usuário"

  defp initials(%{name: name, email: email}) do
    source = if is_binary(name) and String.trim(name) != "", do: name, else: email

    source
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
