defmodule Cryptor.Analysis do
  @moduledoc """
   Server Analysis
  """

  use GenServer
  alias Cryptor.Trader
  alias Cryptor.Order

  defstruct orders: [], current_value: nil, coin: nil

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
             state.order_list,
             fn %Order{order_id: id} ->
               id == order.order_id
             end
           )
     }}
  end

  @impl true
  def handle_info(:get_currency_price, %__MODULE__{orders: []} = state) do
    analisys()
    {:noreply, state}
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
        orders
        |> Enum.each(&start_transaction(current_value, &1))

        analisys()
        {:noreply, %{state | current_value: current_value}}
    end
  end

  def start_transaction(current_value, order) do
    Task.start(fn -> Trader.analyze_transaction(current_value, order) end)
  end

  defp analisys, do: Process.send_after(self(), :get_currency_price, Enum.random(7_000..8_000))
end
