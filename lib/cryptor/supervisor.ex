defmodule Cryptor.CurrencySupervisor do
  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], name: CurrencySupervisor)
  end

  @impl true
  def init(_) do
    applications =
      Cryptor.Trader.get_currencies()
      |> Enum.with_index()
      |> Enum.map(fn {currency, index} ->
        Supervisor.child_spec({Cryptor.CurrencyServer, %{currency: currency}}, id: index)
      end)

    children = applications

    Supervisor.init(children, strategy: :one_for_one)
  end
end
