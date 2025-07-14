defmodule InheritTest do
  use ExUnit.Case

  defmodule Foo do
    use Inherit, [
      a: 1
    ]

    def add(a, b) do
      a + b
    end
  end

  defmodule Bar do
    use Foo, [
      b: 2
    ]
  end

  test "Bar inherits fields and public functions from Foo" do
    bar = %Bar{}
    assert Bar.add(bar.a, bar.b) == 3
  end
end
