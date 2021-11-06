defmodule Cryptor.DynamicSupervisor do
  @moduledoc """
   Analysis Supervisor
  """
  use DynamicSupervisor, restart: :permanent

  def start_link(attrs),
    do: DynamicSupervisor.start_link(__MODULE__, attrs, name: ServersSupervisor)

  @impl true
  def init(_init_arg), do: DynamicSupervisor.init(strategy: :one_for_one)
end
