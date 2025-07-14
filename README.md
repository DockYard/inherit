# Inherit

Inherit provides a way to create pseudo-inheritance in Elixir by allowing modules to inherit struct fields and delegate function calls from other modules.

## Features

- **Struct inheritance**: Child modules inherit all fields from parent modules
- **Function delegation**: Public functions from parent modules are automatically delegated
- **Field merging**: Child modules can add additional fields to inherited structs
- **Overridable functions**: Inherited functions can be overridden in child modules

## Usage

### Making a module inheritable

Use `Inherit` in your module and define struct fields:

```elixir
defmodule Person do
  use Inherit, [
    name: "",
    age: 0
  ]

  def greet(person) do
    "Hello, I'm #{person.name} and I'm #{person.age} years old"
  end

  def adult?(person) do
    person.age >= 18
  end
end
```

### Inheriting from a module

Use the parent module in your child module and specify additional fields:

```elixir
defmodule Employee do
  use Person, [
    salary: 0,
    department: ""
  ]

  # Override parent function
  def greet(employee) do
    "Hi, I'm #{employee.name}, I work in #{employee.department}"
  end
end
```

### Using the inherited module

```elixir
# Create an Employee struct with inherited fields
employee = %Employee{
  name: "John",
  age: 30,
  salary: 50000,
  department: "Engineering"
}

# Call overridden function
Employee.greet(employee)
# => "Hi, I'm John, I work in Engineering"

# Call inherited function
Employee.adult?(employee)
# => true
```

## How it works

1. **Parent module setup**: When you `use Inherit`, the module becomes inheritable and defines its own struct
2. **Inheritance**: When you `use ParentModule`, the child module:
   - Inherits all struct fields from the parent
   - Adds any additional fields specified
   - Delegates all public functions from the parent module
   - Makes inherited functions overridable

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `inherit` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:inherit, "~> 0.1.0"}
  ]
end
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/inherit>.

