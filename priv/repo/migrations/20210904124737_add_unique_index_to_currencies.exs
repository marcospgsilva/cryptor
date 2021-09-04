defmodule Cryptor.Repo.Migrations.AddUniqueIndexToCurrencies do
  use Ecto.Migration

  def change do
    create unique_index(:currencies, [:coin])
  end
end
