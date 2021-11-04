defmodule Cryptor.Server do
  use GenServer
  alias Cryptor.Accounts
  alias Cryptor.Accounts.User
  alias Cryptor.BotServer
  alias Cryptor.ProcessRegistry
  alias Cryptor.Analysis
  alias Cryptor.Orders.OrdersAgent
  alias Cryptor.Orders.PendingOrdersAgent

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{users: nil}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state, {:continue, :get_users}}
  end

  @impl true
  def handle_continue(:get_users, state) do
    users = Accounts.get_users()
    {:noreply, %{state | users: users}, {:continue, :start_analysis_server}}
  end

  @impl true
  def handle_continue(:start_analysis_server, %{users: []} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_continue(:start_analysis_server, %{users: users} = state) do
    Enum.each(users, &start_analysis_server(&1.id))
    {:noreply, state, {:continue, :start_orders_agent_server}}
  end

  @impl true
  def handle_continue(:start_orders_agent_server, %{users: users} = state) do
    Enum.each(users, &start_orders_agent(&1.id))
    {:noreply, state, {:continue, :start_pending_orders_agent_server}}
  end

  @impl true
  def handle_continue(:start_pending_orders_agent_server, %{users: users} = state) do
    Enum.each(users, &start_pending_orders_agent(&1.id))
    {:noreply, state, {:continue, :start_bots}}
  end

  @impl true
  def handle_continue(:start_bots, %{users: users} = state) do
    users
    |> Enum.each(fn user = %User{} ->
      case user.bots
           |> Enum.filter(& &1.active) do
        [] ->
          nil

        active_bots ->
          active_bots
          |> Enum.each(&start_bot_server(&1, user.id))
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:start_servers, user}, state) do
    start_analysis_server(user.id)
    start_orders_agent(user.id)
    start_pending_orders_agent(user.id)

    {:noreply, %{state | users: [user | state.users]}}
  end

  def start_bot_server(bot, user_id) do
    bot_name = ProcessRegistry.via_tuple({user_id, "#{bot.currency}Server"})
    add_to_dynamic_supervisor(BotServer, %{name: bot_name, user_id: user_id, bot: bot})
  end

  def start_analysis_server(user_id) do
    analysis_name = ProcessRegistry.via_tuple({user_id, "AnalysisServer"})
    add_to_dynamic_supervisor(Analysis, %{name: analysis_name, user_id: user_id})
  end

  def start_orders_agent(user_id) do
    orders_agent_name = ProcessRegistry.via_tuple({user_id, "OrdersAgent"})
    result = add_to_dynamic_supervisor(OrdersAgent, %{name: orders_agent_name, user_id: user_id})
    IO.inspect(result, label: "RESULT")
    result
  end

  def start_pending_orders_agent(user_id) do
    pending_orders_agent_name = ProcessRegistry.via_tuple({user_id, "PendingOrdersAgent"})
    add_to_dynamic_supervisor(PendingOrdersAgent, %{name: pending_orders_agent_name})
  end

  defp add_to_dynamic_supervisor(module, state) do
    DynamicSupervisor.start_child(
      AnalysisSupervisor,
      {module, state}
    )
  end
end
