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
  - `super(args...)` - Calls the parent implementation when overriding inherited functions
  - `defwithhold` - Prevents specified functions from being inherited by child modules

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

  @doc false
  defmacro from(parent, fields) do
    Module.put_attribute(__CALLER__.module, :"$inherit:parent", parent)

    ancestors_quoted =
      Inherit.get_inheritable_functions(parent)
      |> Enum.map(fn({ancestor_module, functions}) ->
        def_quoted = Enum.map(functions, fn({name, meta}) ->
          args = Inherit.build_args(meta.arity)
          
          quote location: :keep do
            def unquote(name)(unquote_splicing(args)) do
              apply(unquote(ancestor_module), unquote(name), [unquote_splicing(args)])
            end
            Inherit.update_function_defs(unquote(name), unquote(meta.arity), %{delegate: true})
          end
        end)

        overridable = Enum.reduce(functions, [], fn
          {name, %{overridable: true} = meta}, acc ->
            [{name, meta.arity}| acc]
          _other, acc -> acc
        end)

        defoverridable_quoted = quote location: :keep do
          defoverridable unquote(overridable)
        end

        use_quoted = if ancestor_module != parent do
          quote location: :keep do
            use unquote(ancestor_module), unquote(Macro.escape(fields))
          end
        else
          []
        end

        quote location: :keep do
          unquote_splicing(def_quoted)
          unquote(defoverridable_quoted)
          unquote(use_quoted)
        end
      end)

    quote location: :keep do
      fields = unquote(parent).__info__(:struct)
        |> Enum.map(&({&1.field, &1.default}))
        |> Keyword.merge(unquote(fields))

      use Inherit, fields

      unquote_splicing(ancestors_quoted)
    end
  end

  def get_inheritable_functions(module) do
    get_ancestors(module)
    |> Enum.reduce([],  fn(ancestor, ancestor_functions) ->
      functions =
        ancestor.__info__(:attributes) |> Keyword.get(:"$inherit:functions", [])
        |> Enum.filter(fn
          {_name, %{delegate: false}} -> true
          _other -> false
        end)

      [{ancestor, functions} | ancestor_functions]
    end)
  end

  @doc """
  Prevents specified functions from being marked as inheritable by child modules.

  This macro removes functions from the inheritance mechanism, ensuring they will
  not be automatically delegated to child modules. Functions marked with 
  `defwithhold` must be defined independently by each module that needs them.

  ## Parameters

  - `keywords_or_behaviour` - A keyword list of `{function_name, arity}` pairs
    specifying which functions should not be inheritable

  ## Example

      defmodule Parent do
        use Inherit, [field: 1]

        def inheritable_function do
          "This will be inherited"
        end

        def non_inheritable_function do
          "This will not be inherited"
        end
        defwithhold non_inheritable_function: 0
      end

      defmodule Child do
        use Parent, []
        
        # Child automatically inherits inheritable_function/0
        # Child does NOT inherit non_inheritable_function/0
        # Must define non_inheritable_function/0 independently if needed
      end

  ## Technical Implementation

  `defwithhold` removes function entries from the module's `$inherit:functions`
  attribute, excluding them from the automatic delegation process during inheritance.
  """
  defmacro defwithhold(keywords_or_behaviour) do
    quote location: :keep do
      Enum.each(unquote(keywords_or_behaviour), fn({name, arity}) ->
        Inherit.remove_function_defs(name, arity)
      end)
    end
  end

  @doc false
  defmacro defoverridable(keywords_or_behaviour) do
    quote location: :keep do
      Kernel.defoverridable(unquote(keywords_or_behaviour))

      Enum.each(unquote(keywords_or_behaviour), fn({name, arity}) ->
        Inherit.update_function_defs(name, arity, %{overridable: true})
      end)
    end
  end

  defmacro def(call, expr \\ nil) do
    quoted_def = quote location: :keep do
      Kernel.def(unquote(call), unquote(expr))
    end

    {name, args} = case call do
      {:when, _, [{name, _, args} | _]} -> {name, args}
      {name, _meta, args} -> {name, args}
    end

    arity_range = case args do
      args when is_list(args) ->
        arity = length(args)
        defaults = Enum.count(args, fn
          {:\\, _meta, _args } -> true
          _other -> false
        end)
        (arity - defaults)..arity
      _other -> 0..0
    end

    quote location: :keep do
      unquote(quoted_def)
      Enum.each(unquote(Macro.escape(arity_range)), fn(arity) ->
        Inherit.update_function_defs(unquote(name), arity, %{overridable: false, delegate: false})
      end)
    end
  end

  @doc false
  defmacro remove_function_defs(name, arity) do
    quote location: :keep, bind_quoted: [name: name, arity: arity] do
      if functions = Module.get_attribute(__MODULE__, :"$inherit:functions") do
        functions =
          Enum.reject(functions, fn
            {^name, %{arity: ^arity}} -> true
            _other -> false
          end)

        Module.put_attribute(__MODULE__, :"$inherit:functions", functions)
      end
    end
  end

  @doc false
  defmacro update_function_defs(name, arity, update_meta) do
    quote location: :keep, bind_quoted: [name: name, arity: arity, update_meta: update_meta] do
      if functions = Module.get_attribute(__MODULE__, :"$inherit:functions") do
        function_idx =
          Enum.find_index(functions, fn
            {^name, %{arity: ^arity}} -> true
            _other -> false
          end)

        {name, meta} =
          case function_idx do
            nil -> {name, %{arity: arity, overridable: false, delegate: false}}
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
        defoverridable: 1,
        defwithhold: 1
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
