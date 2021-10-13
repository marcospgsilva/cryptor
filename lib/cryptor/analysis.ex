defmodule Cryptor.Analysis do
  @moduledoc """
   Each currency has your own Analysis GenServer for trigger buy or sell orders based on the currency current price
  """

  use GenServer
  alias Cryptor.{Trader, Order, Currency}
  alias __MODULE__

  defstruct orders: [],
            current_price: 0.0,
            currency: nil,
            sell_percentage_limit: 1.008,
            buy_percentage_limit: 0.985

  # CLIENT
  def start_link(%{state: state, name: name}),
    do: GenServer.start_link(__MODULE__, state, name: name)

  # SERVER
  @impl true
  def init(%__MODULE__{} = state) do
    schedule_place_orders()
    {:ok, state, {:continue, :get_transaction_limit_percentage}}
  end

  @impl true
  def handle_continue(:get_transaction_limit_percentage, %Analysis{currency: currency} = state) do
    case get_currency_percentages(currency) do
      %Currency{} = currency ->
        {:noreply,
         %{
           state
           | sell_percentage_limit: currency.sell_percentage_limit,
             buy_percentage_limit: currency.buy_percentage_limit
         }, {:continue, :get_current_price}}

      _ ->
        {:noreply, state, {:continue, :get_current_price}}
    end
  end

  @impl true
  def handle_continue(:get_current_price, %Analysis{currency: currency} = state) do
    case Trader.get_currency_price(currency) do
      {:ok, current_price} ->
        analisys()
        {:noreply, %{state | current_price: current_price}}

      _ ->
        analisys()
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:update_transaction_limit_percentage, sell_percentage_limit, buy_percentage_limit},
        %Analysis{currency: currency} = state
      ) do
    update_currency_percentages(currency, sell_percentage_limit, buy_percentage_limit)

    {:noreply,
     %{
       state
       | sell_percentage_limit: sell_percentage_limit,
         buy_percentage_limit: buy_percentage_limit
     }}
  end

  @impl true
  def handle_info(:analyze_orders, %Analysis{orders: []} = state) do
    analisys()
    {:noreply, state}
  end

  @impl true
  def handle_info(
        :analyze_orders,
        %Analysis{orders: orders, currency: currency} = state
      ) do
    case Trader.get_currency_price(currency) do
      {:ok, current_price} ->
        process_transaction(orders, current_price)
        analisys()
        {:noreply, %{state | current_price: current_price}}

      _ ->
        analisys()
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        :place_orders,
        %Analysis{current_price: 0.0} = state
      ) do
    schedule_place_orders()
    {:noreply, state}
  end

  @impl true
  def handle_info(
        :place_orders,
        %Analysis{currency: currency, current_price: current_price} = state
      ) do
    Trader.place_order(:buy, current_price, %Order{coin: currency, type: "buy"})
    schedule_place_orders()
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

  def process_transaction(orders, current_price),
    do: orders |> Enum.each(&start_transaction(current_price, &1))

  def start_transaction(current_price, %Order{} = order),
    do:
      Task.Supervisor.start_child(OrdersSupervisor, fn ->
        Trader.analyze_transaction(current_price, order)
      end)

  defp get_currency_percentages(currency),
    do: with(%Currency{} = currency <- Currency.get_currency(currency), do: currency)

  defp update_currency_percentages(currency, sell_percentage_limit, buy_percentage_limit) do
    Currency.get_currency(currency)
    |> Currency.update_currency(%{
      sell_percentage_limit: sell_percentage_limit,
      buy_percentage_limit: buy_percentage_limit
    })
  end

  defp analisys, do: Process.send_after(self(), :analyze_orders, Enum.random(7_000..8_000))

  def schedule_place_orders, do: Process.send_after(self(), :place_orders, 2000)
end
