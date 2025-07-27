defmodule Baz do
  use Bar, [
    b: 3
  ]

  def allowed do
    parent().allowed() ++ [y: 2]
  end

  def incr(val) do
    parent().incr(val) + 1
  end

  def other(a, b, c) do
    [a, b, c]
  end

  def used?, do: false

  def encode(baz) do
    Map.merge(super(baz), %{baz: 2})
  end
  defoverridable encode: 1
end
