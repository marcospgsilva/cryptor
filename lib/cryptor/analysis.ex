defmodule Cryptor.Analysis do
  @moduledoc """
   Analysis Server
  """

  use GenServer

  alias Cryptor.{
    ProcessRegistry,
    Orders.PendingOrdersAgent,
    Trader,
    Utils
  }

  # CLIENT
  def start_link(%{name: name, user_id: user_id}) do
    GenServer.start_link(
      __MODULE__,
      %{
        user_id: user_id,
        account_info: nil
      },
      name: name
    )
  end

  def get_state(pid), do: GenServer.call(pid, :get_state, Utils.get_timeout())

  # SERVER
  @impl true
  def init(args), do: {:ok, args, {:continue, :get_account_info}}

  @impl true
  def handle_continue(:get_account_info, %{user_id: user_id} = state) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    analysis_pid = pids[:analysis_pid]
    account_info = get_account_info(user_id)

    schedule_update_account_info(analysis_pid)
    {:noreply, %{state | account_info: account_info}, {:continue, :schedule_orders_status}}
  end

  @impl true
  def handle_continue(:schedule_orders_status, %{user_id: user_id} = state) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    schedule_process_orders_status(pids)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _, state), do: {:reply, state, state}

  @impl true
  def handle_info({:process_orders_status, []}, %{user_id: user_id} = state) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    schedule_process_orders_status(pids)
    {:noreply, state}
  end

  @impl true
  def handle_info({:process_orders_status, pending_orders}, %{user_id: user_id} = state) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    check_order_status(pending_orders)
    schedule_process_orders_status(pids)
    {:noreply, state}
  end

  @impl true
  def handle_info(:update_account_info, %{user_id: user_id} = state) do
    pids = Cryptor.ProcessRegistry.get_servers_registry(user_id)
    analysis_pid = pids[:analysis_pid]

    case get_account_info(user_id) do
      nil ->
        schedule_update_account_info(analysis_pid)
        {:noreply, state}

      account_info ->
        schedule_update_account_info(analysis_pid)
        {:noreply, %{state | account_info: account_info}}
    end
  end

  defp check_order_status(peding_orders),
    do: Enum.map(peding_orders, &process_order_status/1)

  defp process_order_status(order) do
    pids = Cryptor.ProcessRegistry.get_servers_registry(order.user_id)

    case Trader.get_order_data(order, order.user_id) do
      %{status: :filled} ->
        PendingOrdersAgent.remove_from_pending_orders_list(pids[:pending_orders_pid], order)
        Trader.process_pending_order(order, order.user_id)

      %{status: :canceled} ->
        PendingOrdersAgent.remove_from_pending_orders_list(pids[:pending_orders_pid], order)
        Cryptor.Orders.update_order(order, %{filled: true, finished: true})

      _ ->
        nil
    end
  end

  defp get_account_info(user_id) do
    case Trader.get_account_info(user_id) do
      {:error, _reason} ->
        nil

      account_info ->
        account_info
    end
  end

  def schedule_update_account_info(analysis_pid),
    do: Process.send_after(analysis_pid, :update_account_info, 8000)

  def schedule_process_orders_status(pids) do
    Process.send_after(
      pids[:analysis_pid],
      {:process_orders_status,
       PendingOrdersAgent.get_pending_orders_list(pids[:pending_orders_pid])},
      8000
    )
  end
end
