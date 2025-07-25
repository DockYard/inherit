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
  defoverridable handle_call: 3

  @impl true
  def init(_) do
    :ignore
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
end

