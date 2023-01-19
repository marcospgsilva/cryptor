defmodule Cryptor.Engine.Transaction do
  alias Cryptor.Engine.EngineServer
  alias Cryptor.Orders.Order
  alias Cryptor.Orders.PendingOrdersAgent
  alias Cryptor.ProcessRegistry
  alias Cryptor.Utils

  def analyze(
        quantity,
        current_price,
        %Order{price: price, coin: currency},
        user_id,
        bot
      )
      when current_price >= price * bot.sell_percentage_limit do
    with :ok <-
           validate_pending_sell_order(:sell, currency, user_id),
         :ok <-
           validate_available_money(
             :sell,
             quantity,
             current_price,
             user_id
           ) do
      :ok
    end
  end

  def analyze(0.0, _, _, _), do: nil

  def validate_pending_sell_order(:sell = method, currency, user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    pending_orders = PendingOrdersAgent.get_pending_orders_list(pids[:pending_orders_pid])

    case find_pending_orders(pending_orders, method, currency) do
      nil -> :ok
      _ -> :error
    end
  end

  def validate_pending_sell_order(_, _, _), do: :ok

  def validate_available_money(:sell, _, _, _), do: :ok

  def validate_available_money(:buy, quantity, newer_price, user_id) do
    with pids <- ProcessRegistry.get_servers_registry(user_id),
         {:ok, available_amount} <-
           pids[:analysis_pid]
           |> get_account_info_data()
           |> Utils.get_available_amount("brl") do
      order_value = quantity * newer_price

      if available_amount > order_value,
        do: :ok,
        else: {:error, :no_enough_money}
    end
  end

  defp find_pending_orders(pending_orders, method, currency) do
    Enum.find(
      pending_orders,
      &(&1.type == Utils.get_order_type(method) && &1.coin == currency)
    )
  end

  defp get_account_info_data(analysis_pid) do
    analysis_pid
    |> EngineServer.get_state()
    |> Map.get(:account_info)
  end
end
