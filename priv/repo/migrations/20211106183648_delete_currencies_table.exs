defmodule Cryptor.Repo.Migrations.DeleteCurrenciesTable do
  use Ecto.Migration

  def change do
    drop_if_exists table(:currencies)
  end
end
