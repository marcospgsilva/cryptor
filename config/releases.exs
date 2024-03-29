import Config

config :cryptor, CryptorWeb.Endpoint,
  server: true,
  http: [port: {:system, "PORT"}],
  url: [host: System.get_env("APP_NAME") <> ".gigalixirapp.com", port: 443]

config :cryptor, Cryptor.Requests,
  load_from_system_env: true,
  trade_api_base_url: System.get_env("TRADE_API_BASE_URL"),
  data_api_base_url: System.get_env("DATA_API_BASE_URL"),
  tapi_id: System.get_env("TAPI_ID"),
  tapi_id_secret_key: System.get_env("TAPI_ID_SECRET_KEY"),
  options: [timeout: 40_000, recv_timeout: 40_000]
