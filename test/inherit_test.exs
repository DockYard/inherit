defmodule InheritTest do
  require Inherit
  use ExUnit.Case

  defmodule Foo do
    use Inherit, [
      assigns: %{},
      list: [],
      a: 1
    ]

    defmacro __using__(fields) do
      quote do
        use GenServer
        unquote(Inherit.setup(__CALLER__, __MODULE__, fields))
        def used?, do: true

        def module do
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
      b: 2,
      c: %{
        a: 1,
        b: {:a, [], [1, 2]}
      }
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

  test "Foo" do
    assert %Foo{}.a == 1
  end

  test "Bar inherits fields and public functions from Foo" do
    %Bar{} = bar = %Bar{}
    assert Bar.add(bar.a, bar.b) == 3
  end

  test "Baz inherits from Bar which inherits from Foo" do
    %Baz{} = baz = %Baz{}
    assert Baz.add(baz.a, baz.b) == 4
  end

  test "can override __using__" do
    assert Baz.used?()
  end

  test "0 arity functions supported" do
    assert Baz.allowed() == [z: 1, y: 2]
  end

  test "overridden __using__ is inherited with proper module scope" do
    assert Qux.module() == Qux
    assert Baz.module() == Baz
    assert Bar.module() == Bar
  end
end
