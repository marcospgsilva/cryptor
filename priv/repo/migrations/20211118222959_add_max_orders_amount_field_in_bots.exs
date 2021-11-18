defmodule Cryptor.Repo.Migrations.AddMaxOrdersAmountFieldInBots do
  use Ecto.Migration

  def change do
    alter table(:bots) do
      add :max_orders_amount, :integer, default: 1
    end
  end
end
