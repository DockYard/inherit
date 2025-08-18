defmodule Utils do
  def print_module(module) do
    split_module =
      Module.split(module)
      |> Enum.join(".")

    String.to_atom("Elixir.#{split_module}")
  end
end
