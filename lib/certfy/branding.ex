defmodule Certfy.Branding do
  @moduledoc """
  Product identity used by the interface and transactional e-mails.

  Values live under `:certfy, :branding` and can be overridden at runtime with
  `BRAND_NAME`, `BRAND_THEME`, `BRAND_MARK` and `BRAND_FROM_EMAIL`. Keeping the
  identity here lets one codebase run with different names and palettes without
  touching the authentication or domain code.
  """

  @defaults %{
    name: "Certifique",
    theme: "certifique",
    mark: "fadesp",
    from_email: "no-reply@certifique.local"
  }

  @doc "Returns the product name shown to users."
  def name, do: get(:name)

  @doc "Returns the CSS theme key applied as `data-brand` on the root element."
  def theme, do: get(:theme)

  @doc "Returns the mark asset key (`fadesp` or `certfy`)."
  def mark, do: get(:mark)

  @doc "Returns the favicon path for the configured mark."
  def favicon, do: if(mark() == "fadesp", do: "/images/favicon.png", else: "/images/favicon.svg")

  @doc "Returns the favicon MIME type for the configured mark."
  def favicon_type,
    do: if(mark() == "fadesp", do: "image/png", else: "image/svg+xml")

  @doc "Returns the sender address for account e-mails."
  def from_email, do: get(:from_email)

  defp get(key) do
    config = Application.get_env(:certfy, :branding, [])

    case Keyword.get(config, key) do
      value when is_binary(value) and value != "" -> value
      _ -> Map.fetch!(@defaults, key)
    end
  end
end
