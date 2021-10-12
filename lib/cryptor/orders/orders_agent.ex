defmodule Cryptor.Orders.OrdersAgent do
  @moduledoc """
  Orders Agent
  """
  use Agent
  alias Cryptor.Order

  def start_link(_), do: Agent.start_link(fn -> Order.get_orders() end, name: __MODULE__)

  @spec get_order_list() :: list(map())
  def get_order_list, do: Agent.get(__MODULE__, & &1)

  @spec add_to_order_list(new_order :: map()) :: list(map())
  def add_to_order_list(new_order) do
    Agent.get_and_update(__MODULE__, fn orders ->
      {orders, [new_order | orders]}
    end)
  end

  @spec remove_from_order_list(new_order :: map()) :: list(map())
  def remove_from_order_list(order_to_be_removed) do
    Agent.get_and_update(__MODULE__, fn orders ->
      {orders, List.delete(orders, order_to_be_removed)}
    end)
  end
end
