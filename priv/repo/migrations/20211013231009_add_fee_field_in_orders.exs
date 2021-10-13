defmodule Cryptor.Repo.Migrations.AddFeeFieldInOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :fee, :string
    end
  end
end
