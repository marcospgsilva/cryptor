defmodule Cryptor.Repo do
  use Ecto.Repo,
    otp_app: :cryptor,
    adapter: Ecto.Adapters.Postgres
end
