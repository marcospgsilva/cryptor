defmodule Cryptor.Analysis do
  @moduledoc """
   Each currency has your own Analysis GenServer for trigger buy or sell orders based on the currency current price
  """

  use GenServer
  alias Cryptor.Trader
  alias Cryptor.Order
  alias Cryptor.Currency
  alias __MODULE__

  defstruct orders: [],
            current_price: 0.0,
            coin: nil,
            sell_percentage_limit: 1.008,
            buy_percentage_limit: 0.985

  # CLIENT
  def start_link(%{state: state, name: name}),
    do: GenServer.start_link(__MODULE__, state, name: name)

  # SERVER
  @impl true
  def init(%__MODULE__{} = state),
    do: {:ok, state, {:continue, :get_transaction_limit_percentage}}

  @impl true
  def handle_continue(:get_transaction_limit_percentage, state) do
    Process.send(self(), :get_transaction_limit_precentage, [])
    {:noreply, state}
  end

  @impl true
  def handle_info(:get_transaction_limit_precentage, %Analysis{coin: coin} = state) do
    %Currency{
      sell_percentage_limit: sell_percentage_limit,
      buy_percentage_limit: buy_percentage_limit
    } = Currency.get_currency(coin)

    analisys()

    {:noreply,
     %{
       state
       | sell_percentage_limit: sell_percentage_limit,
         buy_percentage_limit: buy_percentage_limit
     }}
  end

  @impl true
  def handle_info(
        {:update_transaction_limit_percentage, sell_percentage_limit, buy_percentage_limit},
        %Analysis{coin: coin} = state
      ) do
    Currency.get_currency(coin)
    |> Currency.update_currency(%{
      sell_percentage_limit: sell_percentage_limit,
      buy_percentage_limit: buy_percentage_limit
    })

    {:noreply,
     %{
       state
       | sell_percentage_limit: sell_percentage_limit,
         buy_percentage_limit: buy_percentage_limit
     }}
  end

  @impl true
  def handle_info(:get_currency_price, %__MODULE__{orders: [], coin: coin} = state) do
    case Trader.get_currency_price(coin) do
      nil ->
        analisys()
        {:noreply, state}

      current_price ->
        order = Order.create_base_order(coin, current_price)
        analisys()
        schedule_reset_virtual_order_price()
        {:noreply, %{state | current_price: current_price, orders: [order]}}
    end
  end

  @impl true
  def handle_info(
        :get_currency_price,
        %__MODULE__{orders: orders, coin: coin} = state
      ) do
    case Trader.get_currency_price(coin) do
      nil ->
        analisys()
        {:noreply, state}

      current_price ->
        process_transaction(orders, current_price)
        analisys()
        {:noreply, %{state | current_price: current_price}}
    end
  end

  @impl true
  def handle_info(
        :reset_virtual_order_price,
        %Analysis{orders: [%Order{quantity: 0.0} = order], current_price: current_price} = state
      ) do
    updated_order = %{order | price: current_price}
    schedule_reset_virtual_order_price()
    {:noreply, %{state | orders: [updated_order]}}
  end

  @impl true
  def handle_info(:reset_virtual_order_price, state) do
    schedule_reset_virtual_order_price()
    {:noreply, state}
  end

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

  def process_transaction([first_order | []], current_price),
    do: start_transaction(current_price, first_order)

  def process_transaction(orders, current_price) do
    latest_order = get_latest_order(orders)
    start_transaction(current_price, latest_order)
  end

  def start_transaction(current_price, %Order{} = order),
    do: Task.start(fn -> Trader.analyze_transaction(current_price, order) end)

  defp get_latest_order(orders),
    do:
      orders
      |> Enum.reject(&(&1.quantity == 0.0))
      |> Enum.sort(&(&1.price < &2.price))
      |> List.first()

  defp analisys, do: Process.send_after(self(), :get_currency_price, Enum.random(7_000..8_000))

  def schedule_reset_virtual_order_price(),
    do: Process.send_after(self(), :reset_virtual_order_price, 24 * 60 * 60)
end
