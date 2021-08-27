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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
