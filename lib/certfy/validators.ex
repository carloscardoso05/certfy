defmodule Certfy.Validators do
  import Ecto.Changeset

  def validate_email_format(changeset, field) do
    changeset
    |> validate_format(field, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(field, max: 160)
  end
end
