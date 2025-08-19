defmodule Foo do
  use GenServer
  require Logger

  # @derive {Inspect, only: [:list]}
  #
  use Inherit, [
    assigns: %{},
    list: [],
    a: 1,
    z: %{}
  ]

  defmacro __using__(fields) do
    quote location: :keep do
      use GenServer
      require Inherit
      Inherit.from(unquote(__MODULE__), unquote(fields))

      def used?, do: true
      defoverridable used?: 0

      def init(opts \\ []) do
        :ignore
      end
      defwithhold init: 0, init: 1

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

  def handle_call(%{call: false}, _from, state) do
    {:reply, false, state}
  end

  def handle_call({:assign, assigns}, _from, state) when is_list(assigns) do
    {:repl, {:list, assigns}, state}
  end


  def handle_call({:assign, assigns}, _from, state) when is_map(assigns) do
    {:reply, {:map, assigns}, state}
  end
  defoverridable handle_call: 3

  def log(msg) do
    Logger.info(msg)
  end

  @impl true
  @doc false
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{refs: refs} = object) when is_map_key(refs, ref) do
    object = do_down(object, Map.get(refs, ref), [])
    {:noreply, object}
  end

  defp do_down(object, _ref, []) do
    object
  end

  @impl true
  def init(_opts \\ []) do
    :ignore
  end
  defwithhold init: 0, init: 1

  def incr(val, by \\ 1) when is_integer(val) do
    val  + by
  end
  defoverridable [incr: 1, incr: 2]

  def allowed,
    do: []
  defoverridable allowed: 0

  def add(a, b) when is_integer(a) and is_integer(b) do
    do_adder(a, b)
  end

  defp do_adder(a, b) do
    a + b
  end

  def encode(foo) when is_integer(foo) do
    encode(%{foo: foo})
  end

  def encode(foo) do
    foo
  end
  defoverridable encode: 1

  def module do
    Utils.print_module(__MODULE__)
  end
  defoverridable module: 0
end

