defmodule Cryptor.Trader.Server do
  @moduledoc """
   Trader Server
  """

  use GenServer
  alias Cryptor.Analysis
  alias Cryptor.Trader
  alias Cryptor.Order
  alias Cryptor.Trader.PendingOrders

  @currencies ["BTC", "LTC", "XRP", "ETH", "USDC", "BCH"]

  def get_currencies, do: @currencies

  # CLIENT
  def start_link(_attrs) do
    GenServer.start_link(
      __MODULE__,
      %{
        pid_list: [],
        order_list: init_orders(),
        account_info: Trader.get_account_info()
      },
      name: TradeServer
    )
  end

  def init_orders, do: Order.get_orders()

  def add_order(nil), do: nil

  def add_order(%Order{} = order) do
    add_order_to_server(order)
    Process.send(TradeServer, {:put_order, order}, [])
  end

  def remove_order(nil), do: nil

  def remove_order(%Order{} = order) do
    remove_order_from_server(order)
    Process.send(TradeServer, {:pop_order, order}, [])
  end

  def process_pending_order(%{buy_order_id: _buy_order_id} = order),
    do: Trader.remove_and_update_order(order)

  def process_pending_order(order),
    do: Trader.create_and_add_order(order)

  def start_currencies_analysis(currencies) do
    currencies
    |> Enum.map(fn coin ->
      DynamicSupervisor.start_child(
        OrdersSupervisor,
        {Analysis, %{state: %Analysis{coin: coin}, name: String.to_atom(coin <> "Server")}}
      )
      |> elem(1)
    end)
  end

  def add_orders_to_analysis(order_list), do: Enum.each(order_list, &add_order_to_server/1)

  def add_order_to_server(%Order{} = order) when order.coin in @currencies,
    do: GenServer.cast(String.to_existing_atom(order.coin <> "Server"), {:add_order, order})

  def add_order_to_server(_), do: :ok

  def remove_order_from_server(%Order{} = order),
    do: GenServer.cast(String.to_existing_atom(order.coin <> "Server"), {:remove_order, order})

  # SERVER
  @impl true
  def init(args), do: {:ok, args, {:continue, :start_process_coin}}

  @impl true
  def handle_info({:process_orders_status, []}, state) do
    schedule_process_orders_status()
    {:noreply, state}
  end

  @impl true
  def handle_info({:process_orders_status, pending_orders}, state) do
    check_order_status(pending_orders)
    schedule_process_orders_status()
    {:noreply, state}
  end

  @impl true
  def handle_info({:put_order, order}, state),
    do: {:noreply, %{state | order_list: [order | state.order_list]}}

  @impl true
  def handle_info({:pop_order, order}, state) do
    {:noreply,
     %{
       state
       | order_list: List.delete(state.order_list, order)
     }}
  end

  @impl true
  def handle_info(:update_account_info, state) do
    case Trader.get_account_info() do
      nil ->
        schedule_update_account_info()
        {:noreply, state}

      account_info ->
        schedule_update_account_info()
        {:noreply, %{state | account_info: account_info}}
    end
  end

  @impl true
  def handle_continue(:start_process_coin, %{order_list: order_list} = state) do
    pid_list = start_currencies_analysis(@currencies)
    add_orders_to_analysis(order_list)

    schedule_update_account_info()
    schedule_process_orders_status()
    {:noreply, %{state | pid_list: pid_list}}
  end

  defp check_order_status(peding_orders) do
    peding_orders
    |> Enum.each(fn order ->
      with :done <- Trader.get_order_status(order) do
        process_pending_order(order)
        PendingOrders.remove_from_pending_orders_list(order)
      end
    end)
  end

  def schedule_update_account_info,
    do: Process.send_after(TradeServer, :update_account_info, 10_000)

  def schedule_order_status(attrs),
    do: Process.send_after(TradeServer, {:get_order_status, attrs}, 8000)

  def schedule_process_orders_status,
    do:
      Process.send_after(
        TradeServer,
        {:process_orders_status, PendingOrders.get_pending_orders_list()},
        8000
      )
end
