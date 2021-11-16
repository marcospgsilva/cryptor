use Mix.Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :cryptor, Cryptor.Repo,
  username: "postgres",
  password: "postgres",
  database: "cryptor_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cryptor, CryptorWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :cryptor, Cryptor.Requests,
  trade_api_base_url: "https://www.mercadobitcoin.net/tapi/v3/",
  data_api_base_url: "https://www.mercadobitcoin.net/api/",
  trade_api_base_url_v2: "https://api.binance.com/api/v3",
  data_api_base_url_v2: "wss://stream.binance.com:9443/ws",
  tapi_id: "",
  tapi_id_secret_key: ""
