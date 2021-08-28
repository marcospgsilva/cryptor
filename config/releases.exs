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
  tapi_id_secret_key: System.get_env("TAPI_ID_SECRET_KEY")

config :appsignal, :config,
  active: true,
  otp_app: :cryptor,
  name: System.get_env("APPSIGNAL_APP_NAME"),
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY"),
  env: System.get_env("APPSIGNAL_APP_ENV"),
  debug: System.get_env("APPSIGNAL_DEBUG")
