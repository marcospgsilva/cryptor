defmodule Cryptor.Currencies do
  import Ecto.Query
  alias Cryptor.Repo
  alias Cryptor.Currencies.Currency

  def create_currency(attrs),
    do:
      %Currency{}
      |> Currency.changeset(attrs)
      |> Repo.insert()
      |> elem(1)

  def update_currency(nil, _attrs), do: nil

  def update_currency(currency, attrs),
    do:
      currency
      |> Currency.changeset(attrs)
      |> Repo.update()

  def get_currency(coin) do
    Repo.one(
      from currency in Currency,
        where: currency.coin == ^coin
    )
  end
end
