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

  def used?, do: false
end
