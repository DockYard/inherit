defmodule InheritTest do
  use ExUnit.Case

  defmodule Foo do
    use GenServer
    use Inherit, [
      assigns: %{},
      list: [],
      a: 1
    ]

    defmacro __using__(fields) do
      quote do
        use GenServer
        unquote(super(fields))

        def used?, do: true

        def identity do
          __MODULE__
        end
      end
    end

    def init(_) do
      :ok
    end

    def allowed,
      do: []

    def add(a, b) do
      a + b
    end
  end

  defmodule Bar do
    use Foo, [
      b: 2
    ]

    def allowed do
      super() ++ [z: 1]
    end
  end

  defmodule Baz do
    use Bar, [
      b: 3
    ]

    def allowed do
      super() ++ [y: 2]
    end
  end

  defmodule Qux do
    use Baz, [
      c: 4
    ]
  end

  test "Bar inherits fields and public functions from Foo" do
    %Bar{} = bar = %Bar{}
    assert Bar.add(bar.a, bar.b) == 3

    %Baz{} = baz = %Baz{}
    assert Baz.add(baz.a, baz.b) == 4
  end

  test "can override __using__" do
    assert Baz.used?()
  end

  test "0 arity functions supported" do
    assert Baz.allowed() == [z: 1, y: 2]
  end
end
