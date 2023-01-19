defmodule Cryptor.Trader do
  @moduledoc """
   Trader
  """

  alias Cryptor.{
    AmountControl,
    Orders,
    Orders.PendingOrdersAgent,
    Orders.OrdersAgent,
    ProcessRegistry,
    Orders.Order,
    Requests,
    Utils
  }

  @currencies Application.get_env(:cryptor, :currencies)

  def get_currencies, do: @currencies

  def trade(current_price, %Order{coin: currency} = order, user_id, bot) do
    with quantity <- AmountControl.get_quantity(:sell, current_price, order, bot.buy_amount),
         :ok <- Cryptor.Engine.Transaction.analyze(quantity, current_price, order, user_id, bot) do
      place_order(:sell, "BRL#{currency}", current_price, user_id, bot)
    end
  end

  def get_currency_price(coin) do
    with {:ok, %{"ticker" => %{"last" => last}}} <-
           Requests.request(:get, "#{coin}/ticker/") do
      {:ok, String.to_float(last)}
    end
  end

  def get_account_info(user_id) do
    with {:ok, response} <-
           Requests.request(:post, %{tapi_method: "get_account_info"}, user_id) do
      response
    end
  end

  def get_order_data(order, user_id) do
    with {:ok, %{"response_data" => %{"order" => %{"status" => order_status, "fee" => fee}}}} <-
           Requests.request(
             :post,
             %{
               tapi_method: "get_order",
               coin_pair: "BRL#{order.coin}",
               order_id: order.order_id
             },
             user_id
           ) do
      mapped_statuses = Order.mapped_order_statuses()
      %{status: Map.get(mapped_statuses, to_string(order_status)), fee: fee}
    end
  end

  def set_order_status_canceled(order, user_id) do
    Requests.request(
      :post,
      %{
        tapi_method: "cancel_order",
        coin_pair: "BRL#{order.coin}",
        order_id: order.order_id
      },
      user_id
    )
  end

  def place_order(:sell, _, %Order{quantity: 0.0}, _user_id, _bot), do: nil

  def place_order(method, newer_price, %Order{coin: currency} = order, user_id, bot) do
    with quantity <- AmountControl.get_quantity(method, newer_price, order, bot.buy_amount),
         {:ok, response} <- place_order(quantity, method, "BRL#{currency}", newer_price, user_id) do
      process_order(response, order, user_id)
    end
  end

  def place_order(quantity, method, coin_pair, newer_price, user_id) do
    Requests.request(
      :post,
      %{
        tapi_method: Utils.get_tapi_method(method),
        coin_pair: coin_pair,
        quantity: Utils.format_float_with_decimals(quantity),
        limit_price: newer_price,
        async: true
      },
      user_id
    )
  end

  def process_order(
        %{"response_data" => %{"order" => %{"order_type" => 2} = new_order}},
        order,
        user_id
      ) do
    add_to_pending_orders(
      new_order
      |> Utils.build_valid_order()
      |> Map.put(:buy_order_id, order.order_id),
      order,
      user_id
    )
  end

  def process_order(%{"response_data" => %{"order" => new_order}}, order, user_id) do
    add_to_pending_orders(
      Utils.build_valid_order(new_order),
      order,
      user_id
    )
  end

  def add_to_pending_orders(pending_order, _order, user_id) do
    with pids <- ProcessRegistry.get_servers_registry(user_id),
         order <-
           pending_order
           |> Map.put(:user_id, user_id)
           |> Map.from_struct(),
         pending_order <- Orders.create_order(order) do
      PendingOrdersAgent.add_to_pending_orders_list(pids[:pending_orders_pid], pending_order)
    end
  end

  def create_and_add_order(%{user_id: user_id, coin: coin, order_id: order_id, fee: fee}) do
    with pids <- ProcessRegistry.get_servers_registry(user_id, coin),
         loaded_order <- Orders.get_order(order_id, user_id),
         {:ok, order} <- Orders.update_order(loaded_order, %{filled: true, fee: fee}) do
      OrdersAgent.add_to_order_list(pids[:orders_pid], order)
    end
  end

  def remove_and_update_order(%{
        user_id: user_id,
        coin: coin,
        order_id: order_id,
        buy_order_id: buy_order_id
      }) do
    with pids <- ProcessRegistry.get_servers_registry(user_id, coin),
         buy_order <- Orders.get_order(buy_order_id, user_id),
         order <- Orders.get_order(order_id, user_id),
         :ok <- OrdersAgent.remove_from_order_list(pids[:orders_pid], buy_order),
         {:ok, _} <- Orders.update_order(buy_order, %{finished: true}),
         {:ok, order} <- Orders.update_order(order, %{finished: true, filled: true}) do
      Process.send(pids[:bot_pid], {:update_latest_sell_order, order}, [])
    end
  end

  def delete_order(id, user_id) do
    with %{user_id: user_id, coin: coin} = order <- Orders.get_order(id, user_id),
         pids <- ProcessRegistry.get_servers_registry(user_id, coin),
         :ok <- OrdersAgent.remove_from_order_list(pids[:orders_pid], order) do
      Orders.update_order(order, %{finished: true})
    end
  end

  def remove_order_from_pending_list(id, user_id) do
    with pids <- ProcessRegistry.get_servers_registry(user_id),
         order <- Orders.get_order(id, user_id),
         {:ok, _} <- set_order_status_canceled(order, user_id),
         :ok <-
           PendingOrdersAgent.remove_from_pending_orders_list(pids[:pending_orders_pid], order) do
      Orders.update_order(order, %{finished: true, filled: true})
    end
  end

  def process_pending_order(%{buy_order_id: nil} = order, user_id) do
    %{fee: fee} = get_order_data(order, user_id)
    updated_order = %{order | fee: fee}
    create_and_add_order(updated_order)
  end

  def process_pending_order(order, _) do
    remove_and_update_order(order)
  end
end
