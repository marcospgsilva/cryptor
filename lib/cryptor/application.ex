defmodule Cryptor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      {Cluster.Supervisor, [topologies, [name: Cryptor.ClusterSupervisor]]},
      # Start the Ecto repository
      Cryptor.Repo,
      # Start the Telemetry supervisor
      CryptorWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Cryptor.PubSub},
      # Start a worker by calling: Cryptor.Worker.start_link(arg)
      # {Cryptor.Worker, arg},
      {Task.Supervisor, name: ExchangesSupervisor},
      Cryptor.DynamicSupervisor,
      Cryptor.Orders.OrdersAgent,
      Cryptor.Orders.PendingOrdersAgent,
      Cryptor.Trader.TradeServer,
      # Start the Endpoint (http/https)
      CryptorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cryptor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CryptorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
