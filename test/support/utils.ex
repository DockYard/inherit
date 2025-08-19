defmodule Utils do
  def print_module(module) do
    split_module =
      Module.split(module)
      |> Enum.join(".")

    String.to_atom("Elixir.#{split_module}")
  end

  def to_pid(%{pid: pid}) when is_pid(pid) do
    pid
  end

  def to_pid(pid) when is_pid(pid) do
    pid
  end

  defguard is_node_or_pid(node_or_pid) when is_map(node_or_pid) or is_pid(node_or_pid)
end
