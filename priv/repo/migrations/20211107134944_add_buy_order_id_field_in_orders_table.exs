defmodule Cryptor.Repo.Migrations.AddBuyOrderIdFieldInOrdersTable do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :buy_order_id, :integer
    end
  end
end
