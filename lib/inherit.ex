defmodule Inherit do
  @moduledoc """
  Inherit provides pseudo-inheritance in Elixir by allowing modules to inherit
  struct fields, delegate function calls, and override behaviors from parent modules.

  ## Features

  - **Struct inheritance**: Child modules inherit all fields from parent modules
  - **Function delegation**: Public functions from parent modules are automatically delegated
  - **Function overriding**: Parent functions marked with `defoverridable` can be overridden by child modules
  - **Custom `__using__` inheritance**: Parent modules can define custom `__using__` macros that are inherited
  - **Parent module access**: Use `parent()` to access the parent module and call parent functions
  - **Super calls**: Use `super()` to call the original implementation of overridden functions
  - **Deep inheritance chains**: Support for multiple levels of inheritance
  - **GenServer integration**: Works seamlessly with GenServer and other OTP behaviors

  ## Basic Usage

  ### Making a module inheritable

      defmodule Parent do
        use Inherit, [
          field1: "default_value",
          field2: 42
        ]

        def some_function(value) do
          value + 1
        end
        defoverridable some_function: 1  # Child modules can override this
        
        def another_function do
          "parent implementation"  
        end
        # No defoverridable - child modules cannot override this
      end

  ### Inheriting from a module

      defmodule Child do
        use Parent, [
          field3: "additional_field"
        ]

        # Override a parent function (only works if parent used defoverridable)
        def some_function(value) do
          super(value) + 10  # Calls Parent.some_function/1 and adds 10
        end
        defoverridable some_function: 1

        # Access parent module directly  
        def call_parent do
          parent().another_function()
        end
        
        # This would compile with a warning but never be called:
        # def another_function, do: "child implementation"  # Parent didn't use defoverridable!
      end

  ## Advanced Usage

  ### Custom `__using__` macros

  Parent modules can define their own `__using__` macros that will be inherited:

      defmodule BaseServer do
        use GenServer
        use Inherit, [state: %{}]

        defmacro __using__(fields) do
          quote do
            use GenServer
            require Inherit
            Inherit.setup(unquote(__MODULE__), unquote(fields))

            def start_link(opts \\\\ []) do
              GenServer.start_link(__MODULE__, opts, name: __MODULE__)
            end
            defoverridable start_link: 1
          end
        end

        @impl true
        def init(opts) do
          {:ok, struct(__MODULE__, opts)}
        end
      end

  ### Deep inheritance chains

      defmodule GrandParent do
        use Inherit, [a: 1]
        def value(x), do: x
        defoverridable value: 1  # Must mark as overridable for children to override
      end

      defmodule Parent do
        use GrandParent, [b: 2]
        def value(x), do: super(x) + 10
        defoverridable value: 1  # Mark as overridable for further children
      end

      defmodule Child do
        use Parent, [c: 3]
        def value(x), do: super(x) + 100
        defoverridable value: 1
      end

      # Child.value(5) => 115 (5 + 10 + 100)

  ## Important: Function Overriding Rules
  
  **Parent modules control which functions can be overridden by child modules:**
  
  - Functions marked with `defoverridable` in the parent can be overridden by children
  - Functions NOT marked with `defoverridable` cannot be overridden (attempts will compile with warnings but never execute)
  - Child modules must also use `defoverridable` when overriding to allow further inheritance
  
      defmodule Parent do
        use Inherit, [field: 1]
        
        def can_override, do: "parent"
        defoverridable can_override: 0
        
        def cannot_override, do: "parent only"  # No defoverridable!
      end
      
      defmodule Child do
        use Parent, []
        
        def can_override, do: "child"     # This works - parent used defoverridable
        defoverridable can_override: 0
        
        def cannot_override, do: "child"  # Compiles with warning, never called!
      end
      
      # Child.can_override() => "child"
      # Child.cannot_override() => "parent only" (parent's version always used)

  ## Helper Functions

  - `parent()` - Returns the immediate parent module
  - `parent(module)` - Returns the parent of the specified module
  - `super(args...)` - Calls the parent implementation of the current function

  ## Examples

      iex> defmodule Person do
      ...>   use Inherit, [name: "", age: 0]
      ...>   def greet(person) do
      ...>     "Hello, I'm \#{person.name}"
      ...>   end
      ...> end
      iex> defmodule Employee do
      ...>   use Person, [salary: 0, department: ""]
      ...>   def greet(employee) do
      ...>     super(employee) <> " from \#{employee.department}"
      ...>   end
      ...>   defoverridable greet: 1
      ...> end
      iex> emp = %Employee{name: "John", department: "Engineering"}
      iex> Employee.greet(emp)
      "Hello, I'm John from Engineering"
  """

  defmacro parent do
    quote location: :keep do
      parent(unquote(__CALLER__.module))
    end
  end

  defmacro parent(module) do
    quote location: :keep do
      case :code.ensure_loaded(unquote(module)) do
        {:module, module} ->
          module.__info__(:attributes)
          |> Keyword.get(:"$inherit:parent")
          |> case do
            [parent] -> parent
            nil -> nil
          end
        {:error, _} ->
          Module.get_attribute(unquote(module), :"$inherit:parent")
      end
    end
  end

  @doc """
  Creates an inheritable module that can be used by other modules.

  This macro sets up a module to be inherited by defining a `__using__/1` macro
  that delegates function calls and merges struct fields.

  ## Parameters

  - `module` - The module to inherit from
  - `fields` - A keyword list of additional fields to add to the struct
  """
  defmacro from(parent, fields) do
    quote location: :keep do
      fields = unquote(parent).__info__(:struct)
        |> Enum.map(&({&1.field, &1.default}))
        |> Keyword.merge(unquote(fields))

      use Inherit, fields

      for {ancestor_module, functions} <- Inherit.get_inheritable_functions(unquote(parent)) do
        for {name, args} <- functions do
          Inherit.def(name, args) do
            apply(ancestor_module, name, args)
          end
          Inherit.update_function_defs(name, length(List.wrap(args)), %{delegate: true})
        end

        use ancestor_module, fields
      end
    end
  end

  def get_inheritable_functions(module) do
    get_ancestors(module)
    |> Enum.map(fn(ancestor) ->
      functions =
        ancestor.__info__(:attributes) |> Keyword.get(:"$inherit:functions", [])
        |> Enum.filter(fn
          {_name, %{delegate: false}} -> true
          _other -> false
        end)

      [{ancestor, functions}]
    end)
  end

  @doc false
  defmacro defoverridable(keywords_or_behaviour) do
    quote location: :keep do
      Kernel.defoverridable(unquote(keywords_or_behaviour))

      Enum.each(unquote(keywords_or_behaviour), fn({name, arity}) ->
        Inherit.update_function_defs(name, arity, %{overridden: true})
      end)
    end
  end

  defmacro def({name, _meta, args} = call, expr\\ nil) do
    arity = length(List.wrap(args))

    quote location: :keep do
      Kernel.def(unquote(call), unquote(expr))
      Inherit.update_function_defs(unquote(name), unquote(arity), %{overridden: false, delegate: false})
    end
  end

  @doc false
  defmacro update_function_defs(name, arity, update_meta) do
    quote location: :keep, bind_quoted: [name: name, arity: arity, update_meta: update_meta] do
      functions = Module.get_attribute(__MODULE__, :"$inherit:functions")
      function_idx =
        Enum.find_index(functions, fn
          {^name, %{arity: ^arity}} -> true
          _other -> false
        end)

      {name, meta} =
        case function_idx do
          nil -> {name, %{arity: arity, overridden: false, delegate: false}}
          idx -> Enum.at(functions, idx)
        end

      meta = Map.merge(meta, update_meta)

      functions = case function_idx do
        nil -> List.insert_at(functions, -1, {name, meta})
        idx -> List.replace_at(functions, idx, {name, meta})
      end

      Module.put_attribute(__MODULE__, :"$inherit:functions", functions)
    end
  end

  @doc """
  Makes a module inheritable by defining its struct and enabling inheritance.

  This macro sets up a module to be used as a parent for inheritance by other modules.
 
  ## Parameters
 
  - `fields` - A keyword list defining the struct fields and their default values
  """
  defmacro __using__(fields) do
    quote location: :keep do
      Module.register_attribute(__MODULE__, :"$inherit:parent", persist: true)
      Module.register_attribute(__MODULE__, :"$inherit:functions", persist: true)
      Module.put_attribute(__MODULE__, :"$inherit:functions", [])

      import Kernel, except: [
        def: 2,
        defoverridable: 1
      ]
      require Inherit
      import Inherit, only: [
        parent: 0,
        parent: 1,
        def: 2,
        defoverridable: 1
      ]

      defstruct unquote(fields)

      defmacro __using__(fields) do
        quote location: :keep do
          require Inherit
          Inherit.setup(unquote(__MODULE__), unquote(fields))
        end
      end
      defoverridable __using__: 1
    end
  end

  @doc false
  defmacro setup(module, fields) do
    if !parent(__CALLER__.module) do
      quote location: :keep do
        Inherit.from(unquote(module), unquote(fields))
      end
    end
  end

  @doc false
  def build_args(0),
    do: []
  def build_args(arity) do
    Enum.map(1..arity, &({:"var_#{&1}", [], Elixir}))
  end

  defp get_ancestors(module, ancestors \\ [])
  defp get_ancestors(nil, ancestors),
    do: Enum.reverse(ancestors)
  defp get_ancestors(module, ancestors),
    do: get_ancestors(parent(module), [module | ancestors])
end
