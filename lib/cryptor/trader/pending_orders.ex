defmodule Cryptor.Trader.PendingOrders do
  @moduledoc """
   Pending Orders Agent
  """
  use Agent

  def start_link(_), do: Agent.start_link(fn -> [] end, name: PendingOrdersServer)

  @spec get_pending_orders_list() :: list(map())
  def get_pending_orders_list, do: Agent.get(PendingOrdersServer, & &1)

  @spec add_to_pending_orders_list(new_order :: map()) :: list(map())
  def add_to_pending_orders_list(new_order) do
    Agent.get_and_update(PendingOrdersServer, fn pending_orders ->
      {pending_orders, [new_order | pending_orders]}
    end)
  end

  @spec remove_from_pending_orders_list(new_order :: map()) :: list(map())
  def remove_from_pending_orders_list(order_to_be_removed) do
    Agent.get_and_update(PendingOrdersServer, fn pending_orders ->
      {pending_orders, List.delete(pending_orders, order_to_be_removed)}
    end)
  end
end
