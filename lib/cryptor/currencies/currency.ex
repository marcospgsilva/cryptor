defmodule Cryptor.Currencies.Currency do
  @moduledoc """
   Cryptor Currency
  """
  use Ecto.Schema
  import Ecto.Changeset

  @fields [:coin, :sell_percentage_limit, :buy_percentage_limit]

  schema "currencies" do
    field :coin, :string
    field :sell_percentage_limit, :float, default: 1.008
    field :buy_percentage_limit, :float, default: 0.985

    timestamps(type: :utc_datetime)
  end

  def changeset(currency, attrs),
    do:
      currency
      |> cast(attrs, @fields)
      |> validate_required(@fields)
      |> unique_constraint([:coin])
end
