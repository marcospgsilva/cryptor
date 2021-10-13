# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :cryptor,
  ecto_repos: [Cryptor.Repo]

# Configures the endpoint
config :cryptor, CryptorWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "L1qJ2Z9/cy73l7t190YjURNj6g7JJIvN5E9fYT8A+UVsnH0FOkpGJQGQuglu9wxo",
  render_errors: [view: CryptorWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Cryptor.PubSub,
  live_view: [signing_salt: "X09r3sks"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :appsignal, :config,
  active: true,
  otp_app: :cryptor,
  name: System.get_env("APPSIGNAL_APP_NAME"),
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY"),
  env: System.get_env("APPSIGNAL_APP_ENV"),
  debug: System.get_env("APPSIGNAL_DEBUG")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.

config :cryptor, Cryptor.Requests, options: [timeout: 40_000, recv_timeout: 40_000]

import_config "#{Mix.env()}.exs"
