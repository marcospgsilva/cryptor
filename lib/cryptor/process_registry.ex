defmodule Cryptor.ProcessRegistry do
  def via_tuple(key) when is_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  def whereis_name(key) when is_tuple(key) do
    Registry.whereis_name({__MODULE__, key})
  end

  def get_servers_registry(nil), do: nil

  def get_servers_registry(user_id) do
    with analysis_pid <- whereis_name({user_id, "AnalysisServer"}),
         orders_pid <- whereis_name({user_id, "OrdersAgent"}),
         pending_orders_pid <- whereis_name({user_id, "PendingOrdersAgent"}) do
      %{}
      |> Map.put(:analysis_pid, analysis_pid)
      |> Map.put(:orders_pid, orders_pid)
      |> Map.put(:pending_orders_pid, pending_orders_pid)
    end
  end

  def get_servers_registry(user_id, currency) do
    with bot_pid <- whereis_name({user_id, "#{currency}Server"}) do
      user_id
      |> get_servers_registry()
      |> Map.put(:bot_pid, bot_pid)
    end
  end
end
