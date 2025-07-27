defmodule Foo do
  use GenServer

  @derive {Inspect, only: [:list]}

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
      defwithhold module: 0

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

  def handle_call({:assign, assigns}, _from, state) when is_list(assigns) do
    {:repl, {:list, assigns}, state}
  end

  def handle_call({:assign, assigns}, _from, state) when is_map(assigns) do
    {:reply, {:map, assigns}, state}
  end
  defoverridable handle_call: 3

  @impl true
  def init(_) do
    :ignore
  end
  defoverridable init: 1

  def incr(val, by \\ 1) do
    val  + by
  end
  defoverridable [incr: 1, incr: 2]

  def allowed,
    do: []
  defoverridable allowed: 0

  def add(a, b) when is_integer(a) and is_integer(b) do
    a + b
  end

  def encode(foo) when is_integer(foo) do
    encode(%{foo: foo})
  end

  def encode(foo) do
    foo
  end
  defoverridable encode: 1
end

