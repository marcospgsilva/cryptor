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
    ProcessRegistry,
    Orders.PendingOrdersAgent,
    Utils,
    CurrencyServer
  }

  defmodule State do
    defstruct orders: [],
              user_id: nil,
              bot: nil
  end

  # CLIENT
  def start_link(%{state: state, name: name}),
    do: GenServer.start_link(__MODULE__, state, name: name)

  def get_state(pid), do: GenServer.call(pid, :get_state, Utils.get_timeout())

  # SERVER
  @impl true
  def init(%State{user_id: user_id, bot: %Bot{active: true}} = state) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    schedule_place_orders()
    schedule_process_orders_status(pids)
    {:ok, state, {:continue, :get_orders}}
  end

  @impl true
  def init(state), do: {:ok, state, {:continue, :get_orders}}

  @impl true
  def handle_continue(:get_orders, %{bot: bot, user_id: user_id} = state) do
    pids = ProcessRegistry.get_servers_registry(user_id)

    case Orders.OrdersAgent.get_order_list(pids[:orders_pid]) do
      [] ->
        {:noreply, state}

      orders ->
        filtered_orders =
          orders
          |> Enum.filter(fn order -> order.currency == bot.currency end)

        {:noreply, %{state | orders: filtered_orders}}
    end
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
  def handle_info(:analyze_orders, %State{orders: []} = state) do
    analisys()
    {:noreply, state}
  end

  @impl true
  def handle_info(
        :analyze_orders,
        %State{bot: %Bot{currency: currency, active: true}} = state
      ) do
    current_price = CurrencyServer.get_current_price(currency)
    process_transaction(state, current_price)
    analisys()
    {:noreply, state}
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
          bot: bot = %Bot{},
          user_id: user_id
        } = state
      ) do
    case CurrencyServer.get_current_price(bot.currency) do
      0.0 ->
        nil

      current_price ->
        case Orders.get_latest_sell_orders(bot.currency, user_id) do
          [latest_order | _] ->
            if current_price <= latest_order.price * bot.buy_percentage_limit,
              do: place_buy_order(current_price, bot.currency, user_id),
              else: nil

          _ ->
            place_buy_order(current_price, bot.currency, user_id)
        end
    end

    schedule_place_orders()
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:add_order, order}, state),
    do: {:noreply, %{state | orders: [order | state.orders]}}

  @impl true
  def handle_cast({:remove_order, order}, state) do
    {:noreply,
     %{
       state
       | orders: List.delete(state.orders, order)
     }}
  end

  def place_buy_order(current_price, currency, user_id),
    do:
      Task.Supervisor.start_child(
        ExchangesSupervisor,
        fn ->
          Trader.place_order(:buy, current_price, %Order{coin: currency, type: "buy"}, user_id)
        end,
        shutdown: Utils.get_timeout()
      )

  def process_transaction(
        %State{orders: orders, user_id: user_id},
        current_price
      ),
      do: orders |> Enum.each(&start_transaction(current_price, &1, user_id))

  def start_transaction(current_price, order, user_id) do
    Task.Supervisor.start_child(
      ExchangesSupervisor,
      fn ->
        Trader.analyze_transaction(current_price, order, user_id)
      end,
      shutdown: Utils.get_timeout()
    )
  end

  defp analisys, do: Process.send_after(self(), :analyze_orders, Enum.random(7_000..8_000))

  def schedule_place_orders, do: Process.send_after(self(), :place_orders, 5000)

  def schedule_process_orders_status(pids) do
    Process.send_after(
      pids[:analysis_pid],
      {:process_orders_status,
       {PendingOrdersAgent.get_pending_orders_list(pids[:pending_orders_pid]), pids}},
      8000
    )
  end
end
