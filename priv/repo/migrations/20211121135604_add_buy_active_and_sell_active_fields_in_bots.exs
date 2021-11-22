defmodule Cryptor.Repo.Migrations.AddBuyActiveAndSellActiveFieldsInBots do
  use Ecto.Migration

  def change do
    alter table(:bots) do
      add :sell_active, :boolean, default: false
      add :buy_active, :boolean, default: false
    end
  end
end
