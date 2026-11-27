defmodule CertfyWeb.Components.Brand do
  @moduledoc """
  Shared product mark and wordmark.

  Both components read the name from `Certfy.Branding`, so the same markup
  renders the identity of whichever deployment is running.
  """

  use Phoenix.Component

  alias Certfy.Branding

  attr :class, :string, default: "h-9 w-9 brand-mark"
  attr :id, :string, default: "brand-logo"

  def brand_logo(assigns) do
    ~H"""
    <%= if Branding.mark() == "fadesp" do %>
      <img
        id={@id}
        src="/images/brand-mark.png"
        class={@class}
        alt=""
        aria-hidden="true"
      />
    <% else %>
      <svg id={@id} viewBox="0 0 32 32" class={@class} fill="none" aria-hidden="true">
        <circle cx="16" cy="16" r="13" fill="none" stroke="currentColor" stroke-width="2.25" />
        <circle cx="16" cy="16" r="9" fill="none" stroke="currentColor" stroke-width="1" />
        <path
          d="M20.4 12.6a5.2 5.2 0 0 0-4-1.7c-2.9 0-4.9 2.2-4.9 5.1s2 5.1 4.9 5.1c1.6 0 2.9-.6 3.9-1.7l-1.9-1.5c-.5.5-1.1.8-1.9.8-1.3 0-2.2-.9-2.2-2.7s.9-2.7 2.2-2.7c.8 0 1.4.3 1.9.8z"
          fill="currentColor"
        />
      </svg>
    <% end %>
    """
  end

  attr :class, :string, default: "text-xl font-semibold tracking-tight"
  attr :id, :string, default: "brand-name"

  def brand_name(assigns) do
    ~H"""
    <span id={@id} class={@class}>{Branding.name()}</span>
    """
  end
end
