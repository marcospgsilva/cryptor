defmodule Cryptor.Trader.TradeServer do
  @moduledoc """
   Trade Server
  """

  use GenServer

  alias Cryptor.{
    Analysis,
    Order,
    Orders.PendingOrdersAgent,
    Orders.OrdersAgent,
    Trader
  }

  @currencies ["BTC", "LTC", "XRP", "ETH", "USDC", "BCH"]

  def get_currencies, do: @currencies

  # CLIENT
  def start_link(_attrs) do
    GenServer.start_link(
      __MODULE__,
      %{
        order_list: OrdersAgent.get_order_list(),
        account_info: nil
      },
      name: TraderServer
    )
  end

  def get_state, do: :sys.get_state(TraderServer)

  def add_order(%Order{} = order) do
    add_order_to_analysis_server(order)
    OrdersAgent.add_to_order_list(order)
  end

  def add_order(_), do: {:error, :invalid_order}

  def remove_order(%Order{} = order) do
    remove_order_from_analysis_server(order)
    OrdersAgent.remove_from_order_list(order)
  end

  def remove_order(_), do: {:error, :invalid_order}

  def process_pending_order(%{buy_order_id: _buy_order_id} = order),
    do: Trader.remove_and_update_order(order)

  def process_pending_order(order),
    do: Trader.create_and_add_order(order)

  def start_currencies_analysis(currencies) do
    currencies
    |> Enum.map(fn currency ->
      DynamicSupervisor.start_child(
        AnalysisSupervisor,
        {Analysis,
         %{state: %Analysis{currency: currency}, name: String.to_atom(currency <> "Server")}}
      )
      |> elem(1)
    end)
  end

  def add_orders_to_analysis(order_list),
    do: Enum.each(order_list, &add_order_to_analysis_server/1)

  def add_order_to_analysis_server(%Order{} = order) when order.coin in @currencies,
    do: GenServer.cast(String.to_existing_atom(order.coin <> "Server"), {:add_order, order})

  def add_order_to_analysis_server(_), do: :ok

  def remove_order_from_analysis_server(%Order{} = order),
    do: GenServer.cast(String.to_existing_atom(order.coin <> "Server"), {:remove_order, order})

  # SERVER
  @impl true
  def init(args), do: {:ok, args, {:continue, :get_account_info}}

  @impl true
  def handle_continue(:get_account_info, state) do
    account_info = get_account_info()
    schedule_update_account_info()

    {:noreply, %{state | account_info: account_info},
     {:continue, :start_servers_and_schedule_tasks}}
  end

  @impl true
  def handle_continue(:start_servers_and_schedule_tasks, %{order_list: order_list} = state) do
    start_currencies_analysis(@currencies)
    add_orders_to_analysis(order_list)
    schedule_update_account_info()
    schedule_process_orders_status()
    {:noreply, state}
  end

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
  def handle_info(:update_account_info, state) do
    case get_account_info() do
      nil ->
        schedule_update_account_info()
        {:noreply, state}

      account_info ->
        schedule_update_account_info()
        {:noreply, %{state | account_info: account_info}}
    end
  end

  defp check_order_status(peding_orders),
    do:
      peding_orders
      |> Enum.each(&process_order_status/1)

  defp process_order_status(order) do
    Task.Supervisor.start_child(OrdersSupervisor, fn ->
      handle_order_status(order)
    end)
  end

  defp handle_order_status(order) do
    case Trader.get_order_status(order) do
      :filled ->
        process_pending_order(order)
        PendingOrdersAgent.remove_from_pending_orders_list(order)

      :canceled ->
        PendingOrdersAgent.remove_from_pending_orders_list(order)

      _ ->
        nil
    end
  end

  defp get_account_info() do
    case Trader.get_account_info() do
      {:error, _reason} ->
        nil

      account_info ->
        account_info
    end
  end

  def schedule_update_account_info,
    do: Process.send_after(TraderServer, :update_account_info, 3000)

  def schedule_order_status(attrs),
    do: Process.send_after(TraderServer, {:get_order_status, attrs}, 10_000)

  def schedule_process_orders_status do
    Process.send_after(
      TraderServer,
      {:process_orders_status, PendingOrdersAgent.get_pending_orders_list()},
      8000
    )
  end
end
