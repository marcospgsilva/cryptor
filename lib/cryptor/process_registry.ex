defmodule Cryptor.ProcessRegistry do
  def via_tuple(key) when is_tuple(key),
    do: {:via, Registry, {__MODULE__, key}}

  def whereis_name(key) when is_tuple(key),
    do: Registry.whereis_name({__MODULE__, key})
end
