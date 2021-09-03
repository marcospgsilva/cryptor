defmodule Cryptor.Analysis do
  @moduledoc """
   Server Analysis
  """

  use GenServer
  alias Cryptor.Trader
  alias Cryptor.Order

  defstruct orders: [], current_value: 0.0, coin: nil

  # CLIENT
  def start_link(%{state: state, name: name}),
    do: GenServer.start_link(__MODULE__, state, name: name)

  # SERVER
  @impl true
  def init(%__MODULE__{} = state) do
    analisys()
    {:ok, state}
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

  @impl true
  def handle_info(:get_currency_price, %__MODULE__{orders: [], coin: coin} = state) do
    case Trader.get_currency_price(coin) do
      nil ->
        analisys()
        {:noreply, state}

      current_value ->
        order = %Order{
          order_id: 0,
          coin: coin,
          quantity: 0.0,
          price: current_value,
          type: "buy"
        }

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
            latest_order =
              orders
              |> Enum.reject(&(&1.quantity == 0.0))
              |> Enum.sort(&(&1.price < &2.price))
              |> List.first()

            start_transaction(current_value, latest_order)
            analisys()
            {:noreply, %{state | current_value: current_value}}
        end
    end
  end

  def start_transaction(current_value, order) do
    Task.start(fn -> Trader.analyze_transaction(current_value, order) end)
  end

  defp analisys, do: Process.send_after(self(), :get_currency_price, Enum.random(7_000..8_000))
end
