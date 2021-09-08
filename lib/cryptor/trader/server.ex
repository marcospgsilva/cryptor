defmodule Cryptor.Trader.Server do
  @moduledoc """
   Trader Server
  """

  use GenServer
  alias Cryptor.Analysis
  alias Cryptor.Trader
  alias Cryptor.Order

  @currencies ["BTC", "LTC", "XRP", "ETH", "USDC", "PAXG", "BCH"]

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

  def init_orders() do
    Order.get_orders()
  end

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
  def init(attrs) do
    {:ok, attrs, {:continue, :start_process_coin}}
  end

  @impl true
  def handle_info({:put_order, order}, state) do
    {:noreply, %{state | order_list: [order | state.order_list]}}
  end

  @impl true
  def handle_info({:pop_order, order}, state) do
    {:noreply,
     %{
       state
       | order_list:
           Enum.reject(
             state.order_list,
             fn %Order{order_id: id} ->
               id == order.order_id
             end
           )
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
  def handle_info({:get_order_status, order}, state) do
    case Trader.get_order_status(order) do
      4 ->
        Order.create_order(order) |> add_order()

      3 ->
        nil

      _ ->
        schedule_order_status(order)
    end

    {:noreply, state}
  end

  @impl true
  def handle_continue(:start_process_coin, %{order_list: order_list} = state) do
    pid_list = start_currencies_analysis(@currencies)
    add_orders_to_analysis(order_list)

    schedule_update_account_info()
    {:noreply, %{state | pid_list: pid_list}}
  end

  def schedule_update_account_info(),
    do: Process.send_after(TradeServer, :update_account_info, 10_000)

  def schedule_order_status(attrs),
    do: Process.send_after(TradeServer, {:get_order_status, attrs}, 8000)
end
