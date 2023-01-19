defmodule Cryptor.CurrencySupervisor do
  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], name: CurrencySupervisor)
  end

  @impl true
  def init(_) do
    children =
      Cryptor.Trader.get_currencies()
      |> Enum.with_index()
      |> Enum.map(fn {currency, index} ->
        Supervisor.child_spec({Cryptor.Currencies.CurrencyServer, %{currency: currency}},
          id: index
        )
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
