defmodule Cryptor.Server do
  @moduledoc false

  use GenServer

  alias Cryptor.Accounts
  alias Cryptor.Bots.BotServer
  alias Cryptor.ProcessRegistry
  alias Cryptor.Analysis
  alias Cryptor.Orders.{OrdersAgent, PendingOrdersAgent}

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{users: nil}, name: __MODULE__)
  end

  def start_servers(user) do
    Process.send(Cryptor.Server, {:start_servers, user}, [])
  end

  @impl true
  def init(state) do
    {:ok, state, {:continue, :get_users}}
  end

  @impl true
  def handle_continue(:get_users, state) do
    create_table()
    users = Accounts.get_users()
    {:noreply, %{state | users: users}, {:continue, :create_cache}}
  end

  def handle_continue(:create_cache, %{users: []} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_continue(:create_cache, %{users: users} = state) do
    Enum.each(users, &persist_keys_cache(&1))
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
    {:noreply, state, {:continue, :start_analysis_server}}
  end

  @impl true
  def handle_continue(:start_analysis_server, %{users: users} = state) do
    Enum.each(users, &start_analysis_server(&1.id))
    {:noreply, state, {:continue, :start_bots}}
  end

  @impl true
  def handle_continue(:start_bots, %{users: users} = state) do
    Enum.each(users, fn user -> Enum.each(user.bots, &start_bot_server(&1, user.id)) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:start_servers, %{id: user_id, bots: bots} = user}, state) do
    persist_keys_cache(user)
    start_analysis_server(user_id)
    start_orders_agent(user_id)
    start_pending_orders_agent(user_id)
    Enum.each(bots, &start_bot_server(&1, user_id))
    {:noreply, %{state | users: [user | state.users]}}
  end

  def start_bot_server(bot, user_id) do
    bot_name = ProcessRegistry.via_tuple({user_id, "#{bot.currency}Server"})

    add_to_dynamic_supervisor(Server, %{
      state: %BotServer.State{user_id: user_id, bot: bot},
      name: bot_name
    })
  end

  def start_analysis_server(user_id) do
    analysis_name = ProcessRegistry.via_tuple({user_id, "AnalysisServer"})
    add_to_dynamic_supervisor(Analysis, %{name: analysis_name, user_id: user_id})
  end

  def start_orders_agent(user_id) do
    orders_agent_name = ProcessRegistry.via_tuple({user_id, "OrdersAgent"})
    add_to_dynamic_supervisor(OrdersAgent, %{name: orders_agent_name, user_id: user_id})
  end

  def start_pending_orders_agent(user_id) do
    pending_orders_agent_name = ProcessRegistry.via_tuple({user_id, "PendingOrdersAgent"})

    add_to_dynamic_supervisor(PendingOrdersAgent, %{
      name: pending_orders_agent_name,
      user_id: user_id
    })
  end

  defp add_to_dynamic_supervisor(module, state) do
    DynamicSupervisor.start_child(
      ServersSupervisor,
      {module, state}
    )
  end

  defp create_table do
    :ets.new(:api_keys, [:named_table])
  end

  defp persist_keys_cache(%{id: id, shared_key: shared_key, api_id: api_id}) do
    :ets.insert(:api_keys, {id, shared_key, api_id})
  end
end
