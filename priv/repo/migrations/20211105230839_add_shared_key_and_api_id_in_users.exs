defmodule Cryptor.Repo.Migrations.AddSharedKeyAndApiIdInUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :shared_key, :string, null: false
      add :api_id, :string, null: false
    end
  end
end
