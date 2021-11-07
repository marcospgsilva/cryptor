defmodule Cryptor.Repo.Migrations.AddFilledFieldInOrdersTable do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :filled, :boolean, default: false
    end
  end
end
