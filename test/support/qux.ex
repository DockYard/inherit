defmodule Qux do
  use Baz, [
    c: 4
  ]

  def incr(val) do
    parent().incr(val) + 1
  end
end

