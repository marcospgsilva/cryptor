defmodule Cryptor.Repo.Migrations.RemoveLimitsFromCurrencyTable do
  use Ecto.Migration

  def change do
    alter table(:currencies) do
      remove :sell_percentage_limit, :float
      remove :buy_percentage_limit, :float
    end
  end
end
