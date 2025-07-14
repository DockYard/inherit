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

  @doc """
  Creates an inheritable module that can be used by other modules.

  This macro sets up a module to be inherited by defining a `__using__/1` macro
  that delegates function calls and merges struct fields.

  ## Parameters

  - `module` - The module to inherit from
  - `fields` - A keyword list of additional fields to add to the struct
  """
  defmacro from(module, fields) do
    module = Macro.expand(module, __CALLER__)
    fields = Macro.expand(fields, __CALLER__)

    functions =
      module.__info__(:functions)
      |> Enum.reject(&(Atom.to_string(elem(&1, 0)) =~ "__"))
      |> Enum.map(fn({name, arity}) -> {name, build_args(arity)} end)

    fields = module.__info__(:struct)
      |> Enum.map(&({&1.field, &1.default}))
      |> Keyword.merge(fields)

    delegate_calls = Enum.map(functions, fn {name, args} ->
      quote location: :keep do
        defdelegate(unquote({name, [], args}), to: unquote(module))
      end
    end)

    overridable_list = Enum.map(functions, fn {name, args} -> {name, length(args)} end)

    quote location: :keep do
      defmacro __using__(fields) do
        quote do
          require Inherit
          Inherit.from unquote(__MODULE__), unquote(fields)
        end
      end
      defstruct unquote(fields)
      unquote_splicing(delegate_calls)
      defoverridable unquote(overridable_list)
    end
  end

  @doc """
  Makes a module inheritable by defining its struct and enabling inheritance.

  This macro sets up a module to be used as a parent for inheritance by other modules.
 
  ## Parameters
 
  - `fields` - A keyword list defining the struct fields and their default values
  """
  defmacro __using__(fields) do
    fields = Macro.expand(fields, __CALLER__)

    quote location: :keep do
      defmacro __using__(fields) do
        quote do
          require Inherit
          Inherit.from unquote(__MODULE__), unquote(fields)
        end
      end
      defstruct unquote(fields)
    end
  end
 
  defp build_args(arity) do
    Enum.map(1..arity, &({:"var_#{&1}", [], Elixir}))
  end
end
