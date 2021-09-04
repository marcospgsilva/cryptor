defmodule Cryptor.Currency do
  @moduledoc """
   Cryptor Currency
  """
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  alias Cryptor.Repo
  alias __MODULE__

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

  def create_currency(attrs),
    do:
      %Currency{}
      |> changeset(attrs)
      |> Repo.insert()
      |> elem(1)

  def update_currency(nil, _attrs), do: nil

  def update_currency(currency, attrs),
    do:
      currency
      |> changeset(attrs)
      |> Repo.update()

  def get_currency(coin) do
    Repo.one(
      from currency in Currency,
        where: currency.coin == ^coin
    )
  end
end
