defmodule I do
  def q(quoted, opts \\ []) do
    IO.puts(opts[:label])
    Macro.to_string(quoted) |> IO.puts()

    quoted
  end
end

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
      quote location: :keep do
        use GenServer
        require Inherit
        Inherit.setup(unquote(__MODULE__), unquote(Macro.escape(fields)))

        def used?, do: true
        defoverridable used?: 0

        def module do
          __MODULE__
        end

        def incr(val) do
          super(val)  + 1
        end
        defoverridable incr: 1
      end
    end

    @impl true
    def handle_call(:get, _from, state) do
      {:reply, state, state}
    end

    @impl true
    def init(_) do
      :ok
    end
    defoverridable init: 1

    def incr(val) do
      val  + 1
    end
    defoverridable incr: 1

    def allowed,
      do: []
    defoverridable allowed: 0

    def add(a, b) do
      a + b
    end
    defoverridable add: 2
  end

  defmodule Bar do
    use Foo, [
      b: 2, c: %{
        a: 1,
        b: {:a, [], [1, 2]}
      }
    ]

    def allowed do
      parent().allowed() ++ [z: 1]
    end

    def incr(val) do
      parent().incr(val) + 1
    end

    def handle_call(:get, _from, state) do
      {:reply, state, state}
    end

    def handle_call(msg, from, state) do
      parent().handle_call(msg, from, state)
    end
  end

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
  end

  defmodule Qux do
    use Baz, [
      c: 4
    ]

    def incr(val) do
      parent().incr(val) + 1
    end
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

  test "properly implements ineritance order of functions" do
    assert Qux.incr(1) == 5
  end
end
