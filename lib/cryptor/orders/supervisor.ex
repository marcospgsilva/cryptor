defmodule Cryptor.Orders.Supervisor do
  @moduledoc """
   Orders Supervisor
  """
  use Supervisor

  def start_link(attrs),
    do: Supervisor.start_link(__MODULE__, attrs, name: OrdersSupervisor)

  @impl true
  def init(_init_arg), do: Supervisor.init([], strategy: :one_for_one)
end
