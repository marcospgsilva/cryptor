defmodule Cryptor.Repo.Migrations.CreateCurrenciesTable do
  use Ecto.Migration

  def change do
    create table(:currencies) do
      add :coin, :string
      add :sell_percentage_limit, :float
      add :buy_percentage_limit, :float

      timestamps()
    end
  end
end
