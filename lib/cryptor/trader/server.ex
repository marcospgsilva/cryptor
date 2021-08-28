defmodule Cryptor.Trader.Server do
  @moduledoc """
   Trader Server
  """

  use GenServer
  alias Cryptor.Analysis
  alias Cryptor.Trader
  alias Cryptor.Order

  @currencies ["LTC", "XRP", "ETH", "USDC", "AXS", "BAT", "ENJ", "CHZ"]

  @orders [
    %{
      order_id: 1,
      coin: "XRP",
      quantity: 1.96132719,
      price: 6.57033,
      type: "buy"
    },
    %{
      order_id: 2,
      coin: "ETH",
      quantity: 0.00109722,
      price: 18_100.29,
      type: "buy"
    },
    %{order_id: 3, coin: "BAT", quantity: 10.43067227, price: 4.77, type: "buy"},
    %{order_id: 4, coin: "CHZ", quantity: 4.80037127, price: 2.06, type: "buy"}
  ]

  def start_link(_attrs) do
    GenServer.start_link(
      __MODULE__,
      %{
        pid_list: [],
        order_list: get_orders(),
        # order_list: Order.get_orders(),
        account_info: Trader.get_account_info()
      },
      name: TradeServer
    )
  end

  def get_orders() do
    case Order.get_orders() do
      [] ->
        @orders
        |> Enum.each(&Order.create_order/1)

      orders ->
        orders
    end
  end

  def add_order(order) do
    add_order_to_server(order)

    GenServer.cast(self(), {:put_order, order})
  end

  def remove_order(order) do
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
    pid_list =
      @currencies
      |> Enum.map(fn coin ->
        DynamicSupervisor.start_child(
          OrdersSupervisor,
          {Analysis, %{state: %Analysis{coin: coin}, name: String.to_atom(coin <> "Server")}}
        )
        |> elem(1)
      end)

    order_list
    |> Enum.each(&add_order_to_server/1)

    {:noreply, %{state | pid_list: pid_list}}
  end

  def add_order_to_server(%Order{} = order) do
    GenServer.cast(String.to_existing_atom(order.coin <> "Server"), {:add_order, order})
  end

  def remove_order_from_server(%Order{} = order) do
    GenServer.cast(String.to_existing_atom(order.coin <> "Server"), {:remove_order, order})
  end
end
