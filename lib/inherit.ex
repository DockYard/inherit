defmodule Inherit do
  @moduledoc """
  Inherit provides a way to create pseudo-inheritance in Elixir by allowing modules
  to inherit struct fields and delegate function calls from other modules.

  ## Usage

  To make a module inheritable, use `Inherit`:

      defmodule Parent do
        use Inherit, [
          field1: "default_value",
          field2: 42
        ]

        def some_function(value) do
          # function implementation
        end
      end

  To inherit from a module:

      defmodule Child do
        use Parent, [
          field3: "additional_field"
        ]

        # Child now has field1, field2, and field3
        # Child can call Parent.some_function/1 directly
      end

  ## Examples

      iex> defmodule Person do
      ...>   use Inherit, [name: "", age: 0]
      ...>   def greet(person) do
      ...>     "Hello, I'm \#{person.name} and I'm \#{person.age} years old"
      ...>   end
      ...> end
      iex> defmodule Employee do
      ...>   use Person, [salary: 0]
      ...> end
      iex> emp = %Employee{name: "John", age: 30, salary: 50000}
      iex> Employee.greet(emp)
      "Hello, I'm John and I'm 30 years old"
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
