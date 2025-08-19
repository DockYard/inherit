defmodule Bar do
  import Utils, only: [
    to_pid: 1,
    is_node_or_pid: 1
  ]

  use Foo, [
    b: 2,
    c: %{
      a: 1,
      b: {:a, [], [1, 2]}
    }
  ]

  defmacro __using__(fields) do
    quote do
      import Utils, only: [
        is_node_or_pid: 1
      ]
      require Inherit
      Inherit.from(unquote(__MODULE__), unquote(fields))
    end
  end

  def capture do
    Enum.each(1..1, &allowed/0) 
  end

  def allowed do
    super() ++ [z: 1]
  end
  defoverridable allowed: 0

  def importer(node_or_pid) when is_node_or_pid(node_or_pid) do
    node_or_pid
  end

  def other_import(node_or_pid) do
    to_pid(node_or_pid)
  end

  def incr(val) do
    __PARENT__.incr(val) + 1
  end
  defoverridable incr: 1

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end


  def handle_call(msg, from, state) do
    __PARENT__.handle_call(msg, from, state)
  end
end
