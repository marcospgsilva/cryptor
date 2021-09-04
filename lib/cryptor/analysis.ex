defmodule Cryptor.Analysis do
  @moduledoc """
   Server Analysis
  """

  use GenServer
  alias Cryptor.Trader
  alias Cryptor.Order
  alias Cryptor.Currency
  alias __MODULE__

  defstruct orders: [],
            current_value: 0.0,
            coin: nil,
            sell_percentage_limit: 1.008,
            buy_percentage_limit: 0.985

  # CLIENT
  def start_link(%{state: state, name: name}),
    do: GenServer.start_link(__MODULE__, state, name: name)

  # SERVER
  @impl true
  def init(%__MODULE__{} = state) do
    {:ok, state, {:continue, :get_transaction_limit_percentage}}
  end

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

      current_value ->
        order = Order.create_base_order(coin, current_value)

        analisys()
        {:noreply, %{state | current_value: current_value, orders: [order]}}
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

      current_value ->
        case Enum.count(orders) <= 1 do
          true ->
            start_transaction(current_value, orders |> List.first())
            analisys()
            {:noreply, %{state | current_value: current_value}}

          _ ->
            latest_order = get_latest_order(orders)
            start_transaction(current_value, latest_order)
            analisys()
            {:noreply, %{state | current_value: current_value}}
        end
    end
  end

  @impl true
  def handle_cast({:add_order, order}, state) do
    {:noreply, %{state | orders: [order | state.orders]}}
  end

  @impl true
  def handle_cast({:remove_order, order}, state) do
    {:noreply,
     %{
       state
       | orders:
           Enum.reject(
             state.orders,
             fn %Order{order_id: id} ->
               id == order.order_id
             end
           )
     }}
  end

  def start_transaction(current_value, %Order{} = order),
    do: Task.start(fn -> Trader.analyze_transaction(current_value, order) end)

  defp get_latest_order(orders),
    do:
      orders
      |> Enum.reject(&(&1.quantity == 0.0))
      |> Enum.sort(&(&1.price < &2.price))
      |> List.first()

  defp analisys, do: Process.send_after(self(), :get_currency_price, Enum.random(7_000..8_000))
end
