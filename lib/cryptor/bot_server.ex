defmodule Cryptor.BotServer do
  @moduledoc """
   Each currency has your own Bot GenServer for trigger buy or sell orders based on the current currency price
  """

  use GenServer

  alias Cryptor.{
    Trader,
    Orders,
    Bots.Bot,
    Orders.Order,
    Orders.OrdersAgent,
    ProcessRegistry,
    Utils
  }

  defmodule State do
    defstruct user_id: nil,
              bot: nil
  end

  # CLIENT
  def start_link(%{state: state, name: name}),
    do: GenServer.start_link(__MODULE__, state, name: name)

  def get_state(pid), do: GenServer.call(pid, :get_state, Utils.get_timeout())

  @impl true
  def init(state), do: {:ok, state, {:continue, :schedule_jobs}}

  @impl true
  def handle_continue(:schedule_jobs, state) do
    analisys()
    schedule_place_orders()
    {:noreply, state}
  end

  def handle_info(:change_bot_activity, %State{bot: bot = %Bot{active: active}} = state) do
    {:ok, bot} = Cryptor.Bot.update_bot(bot, %{active: !active})
    {:noreply, %{state | bot: bot}}
  end

  def handle_info(
        {:update_bot, sell_percentage, buy_percentage, buy_amount},
        %State{bot: bot} = state
      ) do
    {:ok, bot} =
      Cryptor.Bot.update_bot(bot, %{
        sell_percentage_limit: sell_percentage,
        buy_percentage_limit: buy_percentage,
        buy_amount: buy_amount
      })

    {:noreply, %{state | bot: bot}}
  end

  @impl true
  def handle_info(
        :analyze_orders,
        %State{bot: bot = %Bot{currency: currency, active: true, user_id: user_id}} = state
      ) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    current_price = Cryptor.CurrencyServer.get_current_price(currency)

    case OrdersAgent.get_order_list(pids[:orders_pid]) do
      [] ->
        {:noreply, state}

      orders ->
        case orders
             |> Enum.filter(fn order -> order.coin == currency end) do
          [] ->
            nil
            {:noreply, state}

          orders ->
            orders
            |> Enum.each(&Trader.analyze_transaction(current_price, &1, user_id, bot))

            analisys()
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:analyze_orders, state) do
    analisys()
    {:noreply, state}
  end

  @impl true
  def handle_info(
        :place_orders,
        %State{
          bot: bot = %Bot{active: true},
          user_id: user_id
        } = state
      ) do
    pids = ProcessRegistry.get_servers_registry(user_id)

    case Cryptor.CurrencyServer.get_current_price(bot.currency) do
      0.0 ->
        nil

      current_price ->
        case Orders.get_latest_sell_orders(bot.currency, user_id) do
          [latest_order | _] ->
            if current_price <= latest_order.price * bot.buy_percentage_limit,
              do: place_order(current_price, user_id, bot),
              else: nil

          _ ->
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
        end
    end

    schedule_place_orders()
    {:noreply, state}
  end

  @impl true
  def handle_info(:place_orders, state) do
    schedule_place_orders()
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _, state), do: {:reply, state, state}

  defp analisys, do: Process.send_after(self(), :analyze_orders, Enum.random(7_000..8_000))

  def schedule_place_orders,
    do: Process.send_after(self(), :place_orders, Enum.random(7_000..8_000))

  def place_order(current_price, user_id, bot) do
    Trader.place_order(
      :buy,
      current_price,
      %Order{coin: bot.currency, type: "buy"},
      user_id,
      bot
    )
  end
end
