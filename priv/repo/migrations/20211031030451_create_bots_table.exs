defmodule Cryptor.Repo.Migrations.CreateBotsTable do
  use Ecto.Migration

  def change do
    create table(:bots) do
      add :currency, :string
      add :sell_percentage_limit, :float
      add :buy_percentage_limit, :float
      add :sell_amount, :float
      add :buy_amount, :float
      add :active, :boolean
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:bots, [:user_id])
  end
end
