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
      case Code.ensure_compiled(unquote(module)) do
        {:module, _} ->
          # Module is compiled, get from module attributes
          unquote(module).__info__(:attributes)
          |> Keyword.get(:__parent__)
          |> case do
            [parent] -> parent
            nil -> nil
          end
        {:error, _} ->
          if !is_nil(unquote(module)) do
            Module.get_attribute(unquote(module), :__parent__)
          end
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
  defmacro from(parent_module_ast, fields) do
    parent_module = Macro.expand(parent_module_ast, __CALLER__)
    {fields, _} = Macro.expand(fields, __CALLER__) |> Code.eval_quoted()
    ancestor_modules = get_ancestors(parent(parent_module))

    case Code.ensure_compiled(__CALLER__.module) do
      {:module, _} -> nil
      {:error, _} ->
        if !is_nil(__CALLER__.module) do
          Module.put_attribute(__CALLER__.module, :__parent__, parent_module)
        end
    end

    fields = parent_module.__info__(:struct)
      |> Enum.map(&({&1.field, &1.default}))
      |> Keyword.merge(fields)

    quoted_ancestors =
      Enum.reverse(ancestor_modules ++ [parent_module])
      |> Enum.reduce([], fn(ancestor_module, quoted_ancestors) ->
        overridden =
          ancestor_module.__info__(:attributes)
          |> Keyword.get_values(:__overridden__)
          |> Enum.into([], fn([{name, arity}]) -> {name, arity} end)

        functions =
          ancestor_module.__info__(:functions)
          |> Enum.reduce([], fn({name, arity}, functions) ->
            if !(Atom.to_string(name) =~ "__" || arity not in Keyword.get_values(overridden, name)) do
              [{name, build_args(arity)} | functions]
            else
              functions 
            end
          end)

        delegate_calls = Enum.map(functions, fn {name, args} ->
          quote location: :keep do
            def unquote(name)(unquote_splicing(args)) do
              unquote(ancestor_module).unquote(name)(unquote_splicing(args))
            end
          end
        end)

        quoted = quote location: :keep do
          unquote_splicing(delegate_calls)
          defoverridable unquote(overridden)

          unquote(
            if ancestor_module != parent_module do
              quote location: :keep do
                use unquote(ancestor_module), unquote(Macro.escape(fields))
              end
            end
          )
        end

        [quoted | quoted_ancestors]
      end)

    quoted = quote location: :keep do
      use Inherit, unquote(Macro.escape(fields))

      unquote_splicing(quoted_ancestors)
    end

    quoted
  end

  @doc false
  defmacro defoverridable(keywords_or_behaviour) do
    Macro.expand(keywords_or_behaviour, __CALLER__)
    |> Code.eval_quoted()
    |> elem(0)
    |> Enum.each(fn {name, arity} ->
      overridden = Module.get_attribute(__CALLER__.module, :__overridden__)
      if arity not in Keyword.get_values(overridden, name) do
        Module.put_attribute(__CALLER__.module, :__overridden__, {name, arity})
        Module.get_attribute(__CALLER__.module, :__overridden__)
      end
    end)

    quote location: :keep do
      Kernel.defoverridable unquote(keywords_or_behaviour)
    end
  end

  @doc """
  Makes a module inheritable by defining its struct and enabling inheritance.

  This macro sets up a module to be used as a parent for inheritance by other modules.
 
  ## Parameters
 
  - `fields` - A keyword list defining the struct fields and their default values
  """
  defmacro __using__(fields) do
    case Code.ensure_compiled(__CALLER__.module) do
      {:module, _} -> nil
      {:error, _} ->
        if !is_nil(__CALLER__.module) do
          Module.register_attribute(__CALLER__.module, :__parent__, persist: true)
        end
    end

    Module.register_attribute(__CALLER__.module, :__overridden__, persist: true, accumulate: true)

    quote location: :keep do
      import Kernel, except: [
        defoverridable: 1
      ]
      require Inherit
      import Inherit, only: [
        parent: 0,
        parent: 1,
        defoverridable: 1
      ]

      defstruct unquote(fields)

      defmacro __using__(fields) do
        quote do
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

  defp build_args(0),
    do: []
  defp build_args(arity) do
    Enum.map(1..arity, &({:"var_#{&1}", [], Elixir}))
  end

  defp get_ancestors(module, ancestors \\ [])
  defp get_ancestors(nil, ancestors),
    do: Enum.reverse(ancestors)
  defp get_ancestors(module, ancestors),
    do: get_ancestors(parent(module), [module | ancestors])
end
