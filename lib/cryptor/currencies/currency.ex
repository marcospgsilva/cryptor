defmodule Cryptor.Currencies.Currency do
  @moduledoc """
   Cryptor Currency
  """
  use Ecto.Schema
  import Ecto.Changeset

  @fields [:coin]

  schema "currencies" do
    field :coin, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(currency, attrs),
    do:
      currency
      |> cast(attrs, @fields)
      |> validate_required(@fields)
      |> unique_constraint([:coin])
end
