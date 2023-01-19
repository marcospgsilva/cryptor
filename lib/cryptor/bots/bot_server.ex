defmodule Cryptor.Bots.BotServer do
  @moduledoc """
   Each currency has your own Bot GenServer for trigger buy or sell orders based on the current currency price
  """

  use GenServer

  alias Cryptor.Currencies.CurrencyServer
  alias Cryptor.Bots

  alias Cryptor.{
    Trader,
    Orders,
    Orders.Order,
    Orders.OrdersAgent,
    Orders.PendingOrdersAgent,
    Bots.Bot,
    ProcessRegistry,
    Utils
  }

  defmodule State do
    defstruct user_id: nil,
              bot: nil,
              latest_sell_order: []
  end

  # CLIENT
  def start_link(%{state: state, name: name}) do
    GenServer.start_link(__MODULE__, state, name: name)
  end

  def update_bot(pid, %{
    "sell_percentage" => sell_percentage,
    "buy_percentage" => buy_percentage,
    "buy_amount" => buy_amount,
    "max_orders_amount" => max_orders_amount,
    "sell_active" => sell_active,
    "buy_active" => buy_active,
    "bot_active" => bot_active
  }) do
    Process.send(
      pid,
      {
        :update_bot,
        %{
          sell_percentage: Utils.validate_float(sell_percentage),
          buy_percentage: Utils.validate_float(buy_percentage),
          buy_amount: buy_amount,
          max_orders_amount: Utils.validate_float(max_orders_amount) |> round(),
          sell_active: String.to_existing_atom(sell_active),
          buy_active: String.to_existing_atom(buy_active),
          bot_active: String.to_existing_atom(bot_active)
        }
      },
      []
    )
  end

  def get_state(pid) do
    GenServer.call(pid, :get_state, Utils.get_timeout())
  end

  @impl true
  def init(state) do
    {:ok, state, {:continue, :get_latest_sell_order}}
  end

  @impl true
  def handle_continue(
        :get_latest_sell_order,
        %{bot: %{currency: currency}, user_id: user_id} = state
      ) do
    case Orders.get_latest_sell_orders(currency, user_id) do
      [latest_sell_order | _] ->
        {:noreply, %{state | latest_sell_order: latest_sell_order}, {:continue, :schedule_jobs}}

      [] ->
        {:noreply, state, {:continue, :schedule_jobs}}
    end
  end

  @impl true
  def handle_continue(:schedule_jobs, %{bot: %{currency: currency}, user_id: user_id} = state) do
    with %{bot_pid: bot_pid} <- ProcessRegistry.get_servers_registry(user_id, currency) do
      analisys(bot_pid)
      schedule_place_orders(bot_pid)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:update_latest_sell_order, latest_sell_order}, state) do
    {:noreply, %{state | latest_sell_order: latest_sell_order}}
  end

  def handle_info(
        {:update_bot, attrs},
        %State{bot: bot} = state
      ) do
    {:ok, bot} = Bots.update_bot(bot, build_update_bot_attrs(attrs))
    {:noreply, %{state | bot: bot}}
  end

  @impl true
  def handle_info(
        :analyze_orders,
        %State{
          bot:
            %Bot{
              currency: currency,
              active: true,
              user_id: user_id,
              sell_active: true
            } = bot
        } = state
      ) do
    %{orders_pid: orders_pid, bot_pid: bot_pid} =
      ProcessRegistry.get_servers_registry(user_id, currency)

    with current_price <- CurrencyServer.get_current_price(currency),
         orders when not (orders == []) <- OrdersAgent.get_order_list(orders_pid) do
      orders
      |> Enum.filter(&(&1.coin == currency))
      |> start_analyzing(current_price, user_id, bot)
    end

    analisys(bot_pid)
    {:noreply, state}
  end

  @impl true
  def handle_info(:analyze_orders, %{user_id: user_id, bot: %{currency: currency}} = state) do
    user_id
    |> ProcessRegistry.get_servers_registry(currency)
    |> Map.get(:bot_pid)
    |> analisys()

    {:noreply, state}
  end

  @impl true
  def handle_info(
        :place_orders,
        %State{
          bot:
            %Bot{
              active: true,
              buy_active: true,
              max_orders_amount: max_orders_amount,
              currency: currency
            } = bot,
          user_id: user_id
        } = state
      ) do
    pids = ProcessRegistry.get_servers_registry(user_id, currency)

    with pending_orders <- PendingOrdersAgent.get_pending_orders_list(pids[:pending_orders_pid]),
         orders <- OrdersAgent.get_order_list(pids[:orders_pid]),
         pending_orders_amount <- count_orders(pending_orders, bot),
         orders_amount <- count_orders(orders, bot),
         current_price <- CurrencyServer.get_current_price(currency),
         true <-
           valid_to_processing?(
             pending_orders_amount,
             orders_amount,
             max_orders_amount,
             current_price
           ) do
      orders
      |> Enum.filter(&(&1.coin == currency))
      |> process_orders(orders, current_price, state)
    else
      _ -> nil
    end

    schedule_place_orders(pids[:bot_pid])
    {:noreply, state}
  end

  @impl true
  def handle_info(:place_orders, %{user_id: user_id, bot: %{currency: currency}} = state) do
    with %{bot_pid: bot_pid} <- ProcessRegistry.get_servers_registry(user_id, currency) do
      schedule_place_orders(bot_pid)
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def start_analyzing([] = _orders, _current_price, _user_id, _bot), do: nil

  def start_analyzing(orders, current_price, user_id, bot) do
    Enum.each(orders, &Trader.trade(current_price, &1, user_id, bot))
  end

  def place_order(current_price, user_id, bot) do
    Trader.place_order(
      :buy,
      current_price,
      %Order{coin: bot.currency, type: "buy"},
      user_id,
      bot
    )
  end

  defp process_orders(
         filtered_orders,
         orders,
         current_price,
         %{
           bot: bot,
           user_id: user_id,
           latest_sell_order: []
         } = _state
       )
       when orders == [] or filtered_orders == [] do
    place_order(current_price, user_id, bot)
  end

  defp process_orders(
         filtered_orders,
         _orders,
         current_price,
         %{
           bot: bot,
           user_id: user_id,
           buy_percentage_limit: buy_percentage_limit
         } = _state
       ) do
    latest_buy =
      filtered_orders
      |> Enum.sort(&(&1.price < &2.price))
      |> List.first()

    limit = latest_buy.price * buy_percentage_limit

    if current_price <= limit do
      place_order(current_price, user_id, bot)
    end
  end

  defp process_orders(
         _filtered_orders,
         _orders,
         current_price,
         %{
           bot: %{buy_percentage_limit: buy_percentage_limit} = bot,
           user_id: user_id,
           latest_sell_order: latest_sell_order
         } = _state
       ) do
    limit = latest_sell_order.price * buy_percentage_limit

    if current_price <= limit do
      place_order(current_price, user_id, bot)
    end
  end

  defp analisys(bot_pid) do
    schedule(bot_pid, :analyze_orders)
  end

  def schedule_place_orders(bot_pid) do
    schedule(bot_pid, :place_orders)
  end

  defp build_update_bot_attrs(attrs) do
    %{}
    |> Map.put(:sell_percentage_limit, attrs.sell_percentage)
    |> Map.put(:buy_percentage_limit, attrs.buy_percentage)
    |> Map.put(:buy_amount, attrs.buy_amount)
    |> Map.put(:max_orders_amount, attrs.max_orders_amount)
    |> Map.put(:sell_active, attrs.sell_active)
    |> Map.put(:buy_active, attrs.buy_active)
    |> Map.put(:active, attrs.bot_active)
  end

  defp count_orders(orders, bot) do
    orders
    |> Enum.filter(&(&1.coin == bot.currency and &1.type == "buy"))
    |> Enum.count()
  end

  defp valid_to_processing?(
         pending_orders_amount,
         orders_amount,
         max_orders_amount,
         current_price
       ) do
    pending_orders_amount < 1 and
      orders_amount < max_orders_amount and
      current_price > 0.0
  end

  defp schedule(pid, message) do
    Process.send_after(pid, message, Enum.random(7_000..8_000))
  end
end
