defmodule Cryptor.Engine.EngineServer do
  @moduledoc """
   Engine Server
  """

  use GenServer

  alias Cryptor.{
    ProcessRegistry,
    Orders,
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

  def get_state(pid) do
    GenServer.call(pid, :get_state, Utils.get_timeout())
  end

  # SERVER
  @impl true
  def init(args) do
    {:ok, args, {:continue, :get_account_info}}
  end

  @impl true
  def handle_continue(:get_account_info, %{user_id: user_id} = state) do
    with account_info <- get_account_info(user_id),
         _timer_ref <- schedule_update_account_info(user_id) do
      {:noreply, %{state | account_info: account_info}, {:continue, :schedule_orders_status}}
    end
  end

  @impl true
  def handle_continue(:schedule_orders_status, %{user_id: user_id} = state) do
    schedule_process_orders_status(user_id)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:process_orders_status, []}, %{user_id: user_id} = state) do
    schedule_process_orders_status(user_id)
    {:noreply, state}
  end

  @impl true
  def handle_info({:process_orders_status, pending_orders}, %{user_id: user_id} = state) do
    check_order_status(pending_orders)
    schedule_process_orders_status(user_id)
    {:noreply, state}
  end

  @impl true
  def handle_info(:update_account_info, %{user_id: user_id} = state) do
    with account_info when not is_nil(account_info) <- get_account_info(user_id),
         _ <- schedule_update_account_info(user_id) do
      new_state = %{state | account_info: account_info}
      {:noreply, new_state}
    else
      _ -> {:noreply, state}
    end
  end

  defp check_order_status(peding_orders) do
    Enum.map(peding_orders, &process_order_status/1)
  end

  defp process_order_status(%{user_id: user_id} = order) do
    case Trader.get_order_data(order, user_id) do
      %{status: :filled} ->
        PendingOrdersAgent.remove_from_pending_orders_list(user_id, order)
        Trader.process_pending_order(order, user_id)

      %{status: :canceled} ->
        PendingOrdersAgent.remove_from_pending_orders_list(user_id, order)
        Orders.update_order(order, %{filled: true, finished: true})

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

  def schedule_update_account_info(user_id) do
    user_id
    |> ProcessRegistry.get_servers_registry()
    |> Map.get(:analysis_pid)
    |> Process.send_after(:update_account_info, 8000)
  end

  def schedule_process_orders_status(user_id) do
    with %{
           analysis_pid: analysis_pid,
           pending_orders_pid: pending_orders_pid
         } <-
           ProcessRegistry.get_servers_registry(user_id),
         pending_orders <- PendingOrdersAgent.get_pending_orders_list(pending_orders_pid) do
      Process.send_after(analysis_pid, {:process_orders_status, pending_orders}, 8000)
    end
  end
end
