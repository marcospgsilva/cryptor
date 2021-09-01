defmodule Cryptor.Trader.Server do
  @moduledoc """
   Trader Server
  """

  use GenServer
  alias Cryptor.Analysis
  alias Cryptor.Trader
  alias Cryptor.Order

  @currencies ["BTC", "LTC", "XRP", "ETH", "BAT", "CHZ", "USDC", "AXS", "ENJ"]

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
    |> Enum.filter(fn %Order{} = order ->
      order.order_id == 397409190
    end)
    |> Enum.each(&Order.update_order(&1, %{finished: true}))


    Order.get_orders()
    |> Enum.reject(fn %Order{} = order ->
    order.order_id == 397409190
    end)
  end

  def add_order(nil), do: nil

  def add_order(%Order{} = order) do
    add_order_to_server(order)

    GenServer.cast(self(), {:put_order, order})
  end


  def remove_order(nil), do: nil

  def remove_order(%Order{} = order) do
    remove_order_from_server(order)

    GenServer.cast(self(), {:pop_order, order})
  end

  @impl true
  def init(attrs) do
    {:ok, attrs, {:continue, :start_process_coin}}
  end

  @impl true
  def handle_cast({:put_order, order}, state) do
    {:noreply, %{state | order_list: [order | state.order_list]}}
  end

  @impl true
  def handle_cast({:pop_order, order}, state) do
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
  def handle_cast({:update_account_info, nil}, state), do: {:noreply, state}

  @impl true
  def handle_cast({:update_account_info, account_info}, state),
    do: {:noreply, %{state | account_info: account_info}}

  @impl true
  def handle_continue(:start_process_coin, %{order_list: order_list} = state) do
    pid_list = start_currencies_analysis(@currencies)
    add_orders_to_analysis(order_list)

    Process.send_after(self(), {:start_virtual_orders, pid_list}, 10_000)

    update_account_info()
    {:noreply, %{state | pid_list: pid_list}}
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

  @impl true
  def handle_info({:start_virtual_orders, pid_list}, state) do
    add_virtual_orders_to_analysis(pid_list)

    {:noreply, state}
  end

  @impl true
  def handle_info(:update_account_info, state) do
    case Trader.get_account_info() do
      nil ->
        update_account_info()
        {:noreply, state}

      account_info ->
        update_account_info()
        {:noreply, %{state | account_info: account_info}}
    end
  end

  def add_orders_to_analysis(order_list), do: Enum.each(order_list, &add_order_to_server/1)

  def add_order_to_server(%Order{} = order) do
    GenServer.cast(String.to_existing_atom(order.coin <> "Server"), {:add_order, order})
  end

  def remove_order_from_server(%Order{} = order) do
    GenServer.cast(String.to_existing_atom(order.coin <> "Server"), {:remove_order, order})
  end

  def add_virtual_orders_to_analysis(pid_list) do
    pid_list
    |> Enum.filter(fn pid ->
      %{orders: orders} = :sys.get_state(pid)
      orders === []
    end)
    |> create_virtual_order()
  end

  defp create_virtual_order([]), do: nil

  defp create_virtual_order(pid_list) do
    pid_list
    |> Enum.each(fn pid ->
      %{coin: coin, current_value: current_value} = :sys.get_state(pid)

      order = %Order{
        order_id: :rand.uniform(50),
        coin: coin,
        quantity: 0.0,
        price: current_value,
        type: "buy"
      }

      add_order_to_server(order)
    end)
  end

  def update_account_info() do
    Process.send_after(self(), :update_account_info, 20_000)
  end
end
