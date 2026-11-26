defmodule Certfy.Repo do
  use Ecto.Repo,
    otp_app: :certfy,
    adapter: Ecto.Adapters.Postgres
end
