defmodule Cryptor.BotServer do
  @moduledoc """
   Each currency has your own Bot GenServer for trigger buy or sell orders based on the current currency price
  """

  use GenServer

  alias Cryptor.{
    Trader,
    CurrencyServer,
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
  def start_link(%{state: state, name: name}),
    do: GenServer.start_link(__MODULE__, state, name: name)

  def get_state(pid), do: GenServer.call(pid, :get_state, Utils.get_timeout())

  @impl true
  def init(state), do: {:ok, state, {:continue, :get_latest_sell_order}}

  @impl true
  def handle_continue(
        :get_latest_sell_order,
        %{bot: bot, user_id: user_id} = state
      ) do
    case Orders.get_latest_sell_orders(bot.currency, user_id) do
      [latest_sell_order | _] ->
        {:noreply, %{state | latest_sell_order: latest_sell_order}, {:continue, :schedule_jobs}}

      [] ->
        {:noreply, state, {:continue, :schedule_jobs}}
    end
  end

  @impl true
  def handle_continue(:schedule_jobs, state) do
    pids = ProcessRegistry.get_servers_registry(state.user_id, state.bot.currency)
    bot_pid = pids[:bot_pid]

    analisys(bot_pid)
    schedule_place_orders(bot_pid)
    {:noreply, state}
  end

  @impl true
  def handle_info({:update_latest_sell_order, latest_sell_order}, state) do
    {:noreply, %{state | latest_sell_order: latest_sell_order}}
  end

  def handle_info(
        {:update_bot, changes},
        %State{bot: bot} = state
      ) do
    {:ok, bot} =
      Cryptor.Bot.update_bot(bot, %{
        sell_percentage_limit: changes.sell_percentage,
        buy_percentage_limit: changes.buy_percentage,
        buy_amount: changes.buy_amount,
        max_orders_amount: changes.max_orders_amount,
        sell_active: changes.sell_active,
        buy_active: changes.buy_active,
        active: changes.bot_active
      })

    {:noreply, %{state | bot: bot}}
  end

  @impl true
  def handle_info(
        :analyze_orders,
        %State{
          bot: bot = %Bot{currency: currency, active: true, user_id: user_id, sell_active: true}
        } = state
      ) do
    pids = ProcessRegistry.get_servers_registry(user_id, currency)
    current_price = CurrencyServer.get_current_price(currency)

    case OrdersAgent.get_order_list(pids[:orders_pid]) do
      [] ->
        analisys(pids[:bot_pid])
        {:noreply, state}

      orders ->
        case orders
             |> Enum.filter(fn order -> order.coin == currency end) do
          [] ->
            nil
            analisys(pids[:bot_pid])
            {:noreply, state}

          orders ->
            orders
            |> Enum.each(&Trader.analyze_transaction(current_price, &1, user_id, bot))

            analisys(pids[:bot_pid])
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:analyze_orders, state) do
    pids = ProcessRegistry.get_servers_registry(state.user_id, state.bot.currency)
    analisys(pids[:bot_pid])
    {:noreply, state}
  end

  @impl true
  def handle_info(
        :place_orders,
        %State{
          bot: bot = %Bot{active: true, buy_active: true},
          user_id: user_id,
          latest_sell_order: latest_sell_order
        } = state
      ) do
    pids = ProcessRegistry.get_servers_registry(user_id, bot.currency)

    case pids[:pending_orders_pid]
         |> PendingOrdersAgent.get_pending_orders_list()
         |> count_orders(bot) < 1 do
      true ->
        case pids[:orders_pid]
             |> OrdersAgent.get_order_list()
             |> count_orders(bot) < bot.max_orders_amount do
          true ->
            case CurrencyServer.get_current_price(bot.currency) do
              0.0 ->
                nil

              current_price ->
                case latest_sell_order do
                  [] ->
                    case OrdersAgent.get_order_list(pids[:orders_pid]) do
                      [] ->
                        place_order(current_price, user_id, bot)

                      orders ->
                        case orders |> Enum.filter(&(&1.coin == bot.currency)) do
                          [] ->
                            place_order(current_price, user_id, bot)

                          filtered_orders ->
                            latest_buy =
                              filtered_orders |> Enum.sort(&(&1.price < &2.price)) |> List.first()

                            if current_price <= latest_buy.price * bot.buy_percentage_limit,
                              do: place_order(current_price, user_id, bot),
                              else: nil
                        end
                    end

                  latest_order ->
                    if current_price <= latest_order.price * bot.buy_percentage_limit,
                      do: place_order(current_price, user_id, bot),
                      else: nil
                end
            end

          _ ->
            nil
        end

      _ ->
        nil
    end

    schedule_place_orders(pids[:bot_pid])
    {:noreply, state}
  end

  @impl true
  def handle_info(:place_orders, state) do
    pids = ProcessRegistry.get_servers_registry(state.user_id, state.bot.currency)
    schedule_place_orders(pids[:bot_pid])
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _, state), do: {:reply, state, state}

  defp analisys(bot_pid),
    do: Process.send_after(bot_pid, :analyze_orders, Enum.random(7_000..8_000))

  def schedule_place_orders(bot_pid),
    do: Process.send_after(bot_pid, :place_orders, Enum.random(7_000..8_000))

  def place_order(current_price, user_id, bot) do
    Trader.place_order(
      :buy,
      current_price,
      %Order{coin: bot.currency, type: "buy"},
      user_id,
      bot
    )
  end

  defp count_orders(orders, bot) do
    orders
    |> Enum.filter(fn order ->
      order.coin == bot.currency and order.type == "buy"
    end)
    |> Enum.count()
  end
end
