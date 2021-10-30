defmodule Cryptor.Repo.Migrations.AddUserInConditions do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    create index(:orders, [:user_id])
  end
end
