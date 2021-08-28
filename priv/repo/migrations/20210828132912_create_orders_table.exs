defmodule Cryptor.Repo.Migrations.CreateOrdersTable do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :order_id, :integer
      add :coin, :string
      add :quantity, :float
      add :price, :float
      add :type, :string
      add :finished, :boolean, default: false

      timestamps()
    end
  end
end
