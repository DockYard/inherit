defmodule Bar do
  use Foo, [
    b: 2, c: %{
      a: 1,
      b: {:a, [], [1, 2]}
    }
  ]

  def allowed do
    super() ++ [z: 1]
  end
  defoverridable allowed: 0

  def incr(val) do
    parent().incr(val) + 1
  end
  defoverridable incr: 1

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_call(msg, from, state) do
    parent().handle_call(msg, from, state)
  end
end
