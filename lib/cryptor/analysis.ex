defmodule Cryptor.Analysis do
  @moduledoc """
   Analysis Server
  """

  use GenServer

  alias Cryptor.{
    BotServer,
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
    account_info = get_account_info()
    pids = Cryptor.ProcessRegistry.get_servers_registry(user_id)

    schedule_update_account_info(pids[:analysis_pid])
    {:noreply, %{state | account_info: account_info}}
  end

  @impl true
  def handle_call(:get_state, _, state), do: {:reply, state, state}

  @impl true
  def handle_info({:process_orders_status, {[], pids}}, state) do
    BotServer.schedule_process_orders_status(pids)
    {:noreply, state}
  end

  @impl true
  def handle_info({:process_orders_status, {pending_orders, pids}}, state) do
    check_order_status(pending_orders, pids)
    {:noreply, state}
  end

  @impl true
  def handle_info(:update_account_info, %{user_id: user_id} = state) do
    pids = Cryptor.ProcessRegistry.get_servers_registry(user_id)
    analysis_pid = pids[:analysis_pid]

    case get_account_info() do
      nil ->
        schedule_update_account_info(analysis_pid)
        {:noreply, state}

      account_info ->
        schedule_update_account_info(analysis_pid)
        {:noreply, %{state | account_info: account_info}}
    end
  end

  defp check_order_status(peding_orders, pids) do
    Enum.map(peding_orders, &process_order_status/1)

    BotServer.schedule_process_orders_status(pids)
  end

  defp process_order_status(order) do
    pids = Cryptor.ProcessRegistry.get_servers_registry(order.user_id)

    case Trader.get_order_data(order) do
      %{status: :filled} ->
        Trader.process_pending_order(order)
        PendingOrdersAgent.remove_from_pending_orders_list(pids[:pending_orders_pid], order)

      %{status: :canceled} ->
        PendingOrdersAgent.remove_from_pending_orders_list(pids[:pending_orders_pid], order)

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

  def schedule_update_account_info(analysis_pid),
    do: Process.send_after(analysis_pid, :update_account_info, 8000)
end
