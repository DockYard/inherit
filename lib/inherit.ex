defmodule Inherit do
  @moduledoc """
  Inherit provides compile-time pseudo-inheritance in Elixir through sophisticated 
  AST manipulation, allowing modules to inherit struct fields, generate inherited 
  function definitions, and override behaviors from parent modules.

  All inheritance is resolved at compile-time through AST processing, making it 
  highly efficient with no runtime overhead.

  ## Features

  - **Compile-time AST-based inheritance**: Functions are inherited through AST generation, not runtime delegation
  - **Struct field inheritance**: Child modules inherit all fields from parent modules with field merging
  - **Function overriding with `defoverridable`**: Parent functions marked with `defoverridable` can be overridden by child modules
  - **`__PARENT__` module access**: Use `__PARENT__` macro for direct parent module references in function bodies
  - **`super()` calls**: Call the parent implementation when overriding inherited functions (resolved at compile-time)
  - **Function withholding**: Use `defwithhold` to prevent specific functions from being inherited
  - **Deep inheritance chains**: Support for multiple levels of inheritance with proper AST propagation
  - **Custom `__using__` inheritance**: Parent modules can define custom `__using__` macros that are inherited
  - **Private function call detection**: Automatically detects and handles private function calls within inherited functions
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

        # Access parent module directly using __PARENT__
        def call_parent do
          __PARENT__.another_function()
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
            Inherit.from(unquote(__MODULE__), unquote(fields))

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
        defoverridable init: 1
      end

  ### Deep inheritance chains

      defmodule LivingThing do
        use Inherit, [alive: true]
        def life_span(thing), do: thing.alive && 50
        defoverridable life_span: 1  # Must mark as overridable for children to override
      end

      defmodule Animal do
        use LivingThing, [mobile: true]
        def life_span(animal), do: super(animal) + 30
        defoverridable life_span: 1  # Mark as overridable for further children
      end

      defmodule Mammal do
        use Animal, [warm_blooded: true]
        def life_span(mammal), do: super(mammal) + 20
        defoverridable life_span: 1
      end

      # Mammal.life_span(%Mammal{}) => 100 (50 + 30 + 20)

  ### Function withholding with `defwithhold`

      defmodule Parent do
        use Inherit, [field: 1]

        def inherited_function do
          "This will be inherited"
        end

        def private_function do
          "This will not be inherited"
        end
        defwithhold private_function: 0  # Prevents inheritance
      end

      defmodule Child do
        use Parent, []
        # Child.inherited_function() works automatically
        # Child.private_function() raises UndefinedFunctionError
      end

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

  ## How It Works

  The inheritance system operates at compile-time with sophisticated AST processing:

  1. **@before_compile Timing**: Uses `@before_compile` callback for optimal AST access and processing timing
  2. **Intelligent Import Resolution**: Automatically detects imported functions/macros and injects `require` statements
  3. **Dual Inheritance Strategy**: Functions are inherited using two approaches based on their implementation:
     - **AST Copying**: Functions with no private calls have their AST copied directly to child modules
     - **Delegation**: Functions calling private functions are inherited as delegation calls to preserve encapsulation
  4. **Enhanced Private Function Detection**: Uses `Module.definitions_in/2` for accurate private function tracking
  5. **Advanced Argument Processing**: Handles complex argument patterns (guards, defaults, destructuring, pattern matching)
  6. **Callback System**: Supports `before` and `after` callbacks during inheritance for custom setup
  7. **Macro Expansion**: `__PARENT__` and `super()` calls are expanded to direct module references during compilation

  ### Function Inheritance Strategies

  **AST Copying** (for functions with no private calls):
  ```elixir
  # Parent function:
  def simple_add(a, b), do: a + b
  
  # Child gets this AST directly copied:
  def simple_add(a, b), do: a + b  # Same implementation
  ```

  **Delegation** (for functions with private calls):
  ```elixir
  # Parent function:
  defp private_multiply(x), do: x * 2
  def complex_calc(x), do: private_multiply(x) + 1
  
  # Child gets a delegation call:
  def complex_calc(x), do: apply(Parent, :complex_calc, [x])
  ```

  This ensures private functions remain encapsulated in their original module while still allowing inheritance.

  ## API Reference

  - `__PARENT__` - Compile-time macro that expands to the immediate parent module
  - `super(args...)` - Calls the parent implementation when overriding inherited functions (compile-time resolved)
  - `defwithhold` - Prevents specified functions from being inherited by child modules

  ## Real Examples from Refactored Implementation

      # Inheritance chain: Animal -> Mammal -> Primate -> Human (from test suite)
      
      defmodule Animal do
        use GenServer
        use Inherit, [species: "", habitat: "", alive: true]
        
        # Custom __using__ with callback support
        defmacro __using__(fields) do
          before_callback = quote do
            use GenServer  # Ensure GenServer behavior is included
          end
          
          quote do
            require Inherit
            Inherit.from(unquote(__MODULE__), unquote(fields), before: unquote(before_callback))
            
            def breathe(animal), do: "breathing as \#{animal.species}"
            defoverridable breathe: 1
          end
        end
        
        # Function that calls private function - will be DELEGATED in children
        def move(animal, method) do
          validate_movement(method)  # Calls private function
          "Moving by \#{method}"
        end
        defoverridable move: 2
        
        defp validate_movement(method) do
          method in ["walk", "run", "swim"] || raise "Invalid movement: \#{method}"
        end
        
        # Function with no private calls - AST will be COPIED to children  
        def describe(animal) do
          "I am a \#{animal.species}"  # No private function calls
        end
        defoverridable describe: 1
        
        # Function using imported utility with automatic require injection
        def log_species(animal) do
          Logger.info("Species: \#{animal.species}")  # Auto-detects Logger import
        end
      end

      defmodule Mammal do
        use Animal, [warm_blooded: true, fur_type: ""]
        
        def describe(mammal) do
          super(mammal) <> " that is warm-blooded"  # Calls parent via super
        end
        defoverridable describe: 1
      end

      defmodule Primate do
        use Mammal, [opposable_thumbs: true]
        
        def describe(primate) do
          __PARENT__.describe(primate) <> " with opposable thumbs"  # Direct parent call
        end
        defoverridable describe: 1
      end

      defmodule Human do
        use Primate, [language: "", culture: ""]
        
        # This function will never be called because Primate doesn't mark describe/1
        # as defoverridable (demonstrates inheritance control)
        def describe(human) do
          __PARENT__.describe(human) <> " and complex language"
        end
      end

      # Results demonstrate sophisticated inheritance features:
      # move/2 is DELEGATED because it calls private validate_movement/1
      Mammal.move(%Mammal{species: "dog"}, "run")     # => "Moving by run" (delegated to Animal)
      Primate.move(%Primate{species: "chimp"}, "swing") # => "Moving by swing" (delegated through chain)
      
      # describe/1 has AST COPIED and demonstrates override chain
      Human.describe(%Human{species: "Homo sapiens"})  # Uses Primate.describe (not Human due to no defoverridable)
      # => "I am a Homo sapiens that is warm-blooded with opposable thumbs"
      
      # GenServer integration works seamlessly through callback system
      {:ok, pid} = GenServer.start(Human, [])  # Inherits GenServer behavior properly
  """

  @doc """
  Makes a module inheritable by setting up the inheritance infrastructure.

  This macro is used when creating a new inheritable module (root parent). It:
  - Defines a struct with the specified fields
  - Sets up custom macro imports for inheritance functionality  
  - Creates a default `__using__/1` macro for child modules to inherit from this module
  - Establishes the module as the root of an inheritance hierarchy

  ## Parameters

  - `fields` - A keyword list defining the struct fields and their default values

  ## Example

      defmodule Animal do
        use Inherit, [
          species: "",
          habitat: "",
          alive: true
        ]

        def breathe(animal) do
          if animal.alive, do: "breathing", else: "not breathing"
        end
        defoverridable breathe: 1
      end

  This creates an `Animal` module that can be inherited from using `use Animal, [...]`.
  """
  defmacro __using__(fields) do
    quote do
      @before_compile Inherit

      import Kernel, except: [
        def: 1,
        def: 2,
        defoverridable: 1,
      ]

      require Inherit
      import Inherit, only: [
        def: 1,
        def: 2,
        defoverridable: 1,
        defwithhold: 1,
        __PARENT__: 0
      ]

      defstruct unquote(fields)

      defmacro __using__(fields) do
        quote do
          require Inherit
          Inherit.from(unquote(__MODULE__), unquote(fields))
        end
      end
      Kernel.defoverridable __using__: 1
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    ast = get_attribute(env.module, :ast, [])

    ast = 
      case Module.get_attribute(env.module, :"$inherit:before_callback", []) do
        [] -> ast
        before_callback -> [before_callback | ast]
      end

    ast = 
      case Module.get_attribute(env.module, :"$inherit:after_callback", []) do
        [] -> ast
        after_callback -> [after_callback | ast]
      end

    put_attribute(env.module, :ast, ast)
    put_attribute(env.module, :private_funcs, Module.definitions_in(env.module, :defp))
  end

  @doc false
  defmacro __PARENT__ do
    quote do
    end
  end

  @doc false
  defmacro def(call, expr \\ nil) do
    {{name, _meta, args}, guards} = :elixir_utils.extract_guards(call)

    expr = 
      if expr do
        Macro.prewalk(expr, fn
          {:__PARENT__, meta, nil} ->
            case parent(__CALLER__.module) do
              nil ->
                raise "Cannot call __PARENT__ within #{__CALLER__.module} as it is the root ancestor."
              parent_mod ->
                parent_mod = Module.split(parent_mod) |> Enum.map(&String.to_atom/1)
                {:__aliases__, meta, parent_mod}
            end

          other ->
            other
        end)
      else
        expr
      end

    quoted_def = quote do
      Kernel.def(unquote(call), unquote(expr))
    end

    expr =
      if expr do
        Macro.prewalk(expr, fn
          {{:., _combinator_meta, [{:__aliases__, _alias_meta, [:Kernel]}, _name]}, _meta, _args} = ast ->
            ast

          {{:., _combinator_meta, [{:__aliases__, _alias_meta, split_module}, name]}, _meta, args} = ast when is_atom(name) and is_list(args) ->
            define_require(__CALLER__, Module.concat(split_module))

            ast

          {name, meta, args} when is_atom(name) and name not in [:., :=, :/] and is_list(args) ->
            case remote_caller(__CALLER__, name, length(List.wrap(args))) do
              {:def, module} ->
                split_module = Module.split(module) |> Enum.map(&String.to_atom(&1))

                {{:., [], [{:__aliases__, [alias: false], split_module}, name]}, meta, args}
                
              {:defmacro, module} ->
                define_require(__CALLER__, module)

                split_module = Module.split(module) |> Enum.map(&String.to_atom(&1))

                {{:., [], [{:__aliases__, [alias: false], split_module}, name]}, meta, args}

              nil ->
                {name, meta, args}
            end


          other ->
            other
        end)
      else
        nil
      end

    args = case args do
      args when is_list(args) -> args
      _args -> []
    end

    guards = Enum.map(guards, fn(ast) ->
      Macro.prewalk(ast, fn 
        {{:., _module_meta, [{:__aliases__, _alias_meta, split_module}, _name]}, _meta, _args} = ast ->
          define_require(__CALLER__, Module.concat(split_module))

          ast
        {name, meta, args} when is_atom(name) and name not in [:=, :\\, :/, :and, :or, :not] and is_list(args) ->
          arity = length(args)
          Enum.find(__CALLER__.macros, fn({_module, macros}) ->
            arity in Keyword.get_values(macros, name)
          end)
          |> case do
            nil ->
              {name, meta, args}

            {module, _macros} ->
              define_require(__CALLER__, module)

              split_module = Module.split(module) |> Enum.map(&String.to_atom(&1))

              {{:., [], [{:__aliases__, [alias: false], split_module}, name]}, meta, args}
          end

        other -> other
      end)
    end)

    ast =
      get_attribute(__CALLER__.module, :ast, [])
      |> List.insert_at(-1, {:def, name, args, guards, expr})

    put_attribute(__CALLER__.module, :ast, ast)

    quoted_def
  end

  defp remote_caller(caller, name, arity) do
    find = fn(module_functions, name, arity) ->
      Enum.find(module_functions, fn({_module, functions}) ->
        arity in Keyword.get_values(functions, name)
      end)
    end

    if result = find.(caller.functions, name, arity) do
        {:def, elem(result, 0)}
    else
      if result = find.(caller.macros, name, arity) do
        {:defmacro, elem(result, 0)}
      else
        nil
      end
    end
  end

  defp define_require(caller, module) do
    put_attribute_lazy(caller.module, :requires, fn(requires) ->
      List.insert_at(requires || [], -1, module) |> Enum.uniq()
    end)
  end

  @doc """
  Prevents specified functions from being inherited by child modules.

  This macro removes functions from the inheritance mechanism, ensuring they will
  not be automatically generated in child modules through AST processing. Functions 
  marked with `defwithhold` remain exclusive to the module that defines them.

  ## Parameters

  - `keywords` - A keyword list of `{function_name, arity}` pairs specifying 
    which functions should not be inheritable

  ## Example

      defmodule Vehicle do
        use Inherit, [wheels: 4]

        def start_engine do
          "Engine starting..."
        end

        def internal_diagnostics do
          "Running internal checks..."
        end
        defwithhold internal_diagnostics: 0  # Keep this function private to Vehicle
      end

      defmodule Car do
        use Vehicle, [doors: 4]
        
        # Car automatically inherits start_engine/0
        # Car does NOT inherit internal_diagnostics/0
        # Calling Car.internal_diagnostics() would raise UndefinedFunctionError
      end

  ## Technical Implementation

  `defwithhold` removes function entries from the module's AST tracking, excluding 
  them from the inheritance AST generation process.
  """
  defmacro defwithhold(keywords) do
    ast =
      get_attribute(__CALLER__.module, :ast)
      |> Enum.reduce([], fn
        {:def, name, args, _guards, _expr} = def_ast, ast ->
          if length(args) in Keyword.get_values(keywords, name) do
            ast
          else
            [def_ast | ast]
          end
        other_ast, ast -> [other_ast | ast]
      end)
      |> Enum.reverse()

    put_attribute(__CALLER__.module, :ast, ast)
  end

  @doc false
  defmacro defoverridable(keywords) when is_list(keywords) do
    available_funcs =
      get_attribute(__CALLER__.module, :ast, [])
      |> Enum.reduce([], fn
        {:def, name, args, _guards, _expr}, funcs -> 
          arity = length(args)

          defaults = Enum.count(args, fn
            {:\\, _meta, _args} -> true
            _other -> false
          end)

          Enum.reduce(((arity - defaults)..arity), funcs, fn(arity, funcs) ->
            if Enum.member?(funcs, {name, arity}) do
              funcs
            else
              List.insert_at(funcs, -1, {name, arity})
            end
          end)
        _other, funcs -> funcs
      end)

    keywords = Enum.reject(keywords, fn({name, arity}) ->
      arity not in Keyword.get_values(available_funcs, name)
    end)

    if !Enum.empty?(keywords) do
      put_attribute_lazy(__CALLER__.module, :ast, fn(ast) ->
        List.insert_at(ast, -1, {:defoverridable, keywords})
      end)
    end

    quote do
      Kernel.defoverridable(unquote(keywords))
    end
  end

  defmacro defoverridable(behaviour) do
    quote do
      Kernel.defoverridable(unquote(behaviour))
    end
  end

  @doc """
  Establishes inheritance from a parent module to the current module.

  This macro is the core of the inheritance system. It processes the parent module's
  functions and generates appropriate inheritance code based on whether each function
  calls private functions or not. It also merges struct fields from the parent.

  ## Parameters

  - `parent` - The parent module to inherit from
  - `fields` - A keyword list of additional struct fields to define in the child module

  ## Inheritance Process

  1. **Field Merging**: Merges parent struct fields with child fields (child fields override parent fields)
  2. **Function Analysis**: Analyzes each parent function to detect private function calls
  3. **AST Generation**: Generates either direct AST copies or delegation calls based on analysis
  4. **Override Setup**: Preserves `defoverridable` information for child overrides

  ## Generated Code Strategies

  **For functions with no private calls:**
  ```elixir
  # Parent function AST is copied directly:
  def some_function(arg), do: arg + 1
  ```

  **For functions with private calls:**
  ```elixir
  # Delegation call is generated:
  def some_function(arg), do: apply(Parent, :some_function, [arg])
  ```

  ## Example

      defmodule Animal do
        use Inherit, [species: ""]
        
        defp validate_species(animal), do: animal.species != ""
        
        def describe(animal) do
          validate_species(animal)  # Calls private function
          "A \#{animal.species}"
        end
        defoverridable describe: 1
      end

      defmodule Mammal do
        use Animal, [warm_blooded: true]  # Calls Inherit.from(Animal, [warm_blooded: true])
        
        # Mammal.describe/1 is generated as: apply(Animal, :describe, [mammal])
        # This preserves access to Animal's private validate_species/1
      end

  ## Technical Notes

  This macro is automatically called when a module uses another inheritable module.
  It should not be called directly by users - instead use `use ParentModule, fields`.
  """
  defmacro from(parent, fields, quoted_callbacks \\ []) do
    before_callback = Keyword.get(quoted_callbacks, :before, [])
    after_callback = Keyword.get(quoted_callbacks, :after, [])

    Module.put_attribute(__CALLER__.module, :"$inherit:before_callback", before_callback)
    Module.put_attribute(__CALLER__.module, :"$inherit:after_callback", after_callback)

    if !parent(__CALLER__.module) do
      put_attribute(__CALLER__.module, :parent, parent)

      parent_requires = get_attribute(parent, :requires, [])

      requires_ast = Enum.map(parent_requires, fn(module) ->
        quote do
          require unquote(module)
        end
      end)

      put_attribute_lazy(__CALLER__.module, :requires, fn(requires) ->
        parent_requires ++ List.wrap(requires)
      end)

      parent_ast =
        get_attribute(parent, :ast, [])
        |> Enum.map(fn(
          {:def, name, args, guards, expr}) ->
            if local_private_call?(expr, parent) do
              args = build_func_args(args, guards)
              expr = build_func_expr(parent, name, args)

              {:def, name, args, guards, expr}
            else
              {:def, name, args, guards, expr}
            end
          other ->
            other
        end)

      parent_ast_quoted = 
        parent_ast
        |> Enum.map(fn
          {:def, name, args, guards, expr} ->
            call =
              case guards do
                [] -> 
                  {name, [], args}
                _ -> 
                  {:when, [], [{name, [], args}, {:__block__, [], guards}]}
              end

            if expr do
              quote do
                def unquote(call) do
                  unquote(Keyword.get(expr, :do, []))
                end
              end
            else
              quote do
                def unquote(call)
              end
            end

          {:defoverridable, keywords_or_behaviour} ->
            quote do
              defoverridable unquote(keywords_or_behaviour)
            end

          other ->
            other
        end)

      put_attribute_lazy(__CALLER__.module, :ast, fn(ast) ->
        parent_ast ++ List.wrap(ast) 
      end)

      quote do
        unquote_splicing(requires_ast)
        use Inherit, Inherit.merge_from(unquote(parent), unquote(fields))
        unquote_splicing(parent_ast_quoted)
      end
    end
  end

  defp local_private_call?(nil, _module) do
    false
  end

  defp local_private_call?(expr, module) do
    private_funcs = get_attribute(module, :private_funcs)

    {_ast, private_call?} = Macro.prewalk(expr, false, fn
      {name, _meta, nil} = ast, bool when is_atom(name) ->
        {ast, bool}
      {name, _meta, args} = ast, bool when is_atom(name) and is_list(args) ->
        if length(args) in Keyword.get_values(private_funcs, name) do
          {ast, true}
        else
          {ast, bool}
        end
      ast, bool -> {ast, bool}
    end)

    private_call?
  end

  defp build_func_args(args, guards) do
    {_ast, guard_args} = Macro.prewalk(guards, MapSet.new([]), fn 
      {name, _meta, nil} = ast, guard_args when is_atom(name) -> {ast, MapSet.put(guard_args, name)}
      other, guard_args -> {other, guard_args}
    end)

    args
    |> Enum.with_index()
    |> Enum.map(fn
      {{:=, meta, [ast, {name, name_meta, name_context}]}, _idx} when is_list(args) ->
        ast = Macro.prewalk(ast, fn 
          {name, meta, nil} when is_atom(name) ->
            if MapSet.member?(guard_args, name) do
              {name, meta, nil}
            else
              {underscore(name), meta, nil}
            end

          ast -> ast
        end)

        {:= , meta, [ast, {deunderscore(name), name_meta, name_context}]}

      {{:\\, meta, [{name, name_meta, nil}, value]}, _idx} ->
        {:\\, meta, [{deunderscore(name), name_meta, nil}, value]}

      {{name, meta, context}, _idx} when is_atom(name) and (is_atom(context) or is_nil(context)) ->
        {deunderscore(name), meta, context}

      {{type, _meta, _fields} = ast, idx} when type in [:%{}, :{}] ->
        ast = Macro.prewalk(ast, fn 
          {name, meta, nil} when is_atom(name) ->
            if MapSet.member?(guard_args, name) do
              {name, meta, nil}
            else
              {underscore(name), meta, nil}
            end

          ast -> ast
        end)

        {:= , [], [ast, {:"arg#{idx}", [], Elixir}]}

      {literal, _idx} -> literal
    end)
  end

  defp build_func_expr(parent, name, args) do
    args = Enum.map(args, fn
      {:\\, _meta, [arg, _value]}-> arg
      {:=, meta, args} when is_list(args) ->
        {name, _meta, context} = List.last(args)
        {name, meta, context}
      {name, meta, context} when is_atom(name) and is_atom(context) -> {name, meta, context}
      literal -> literal
    end)

    [do: quote do
      apply(unquote(parent), unquote(name), [unquote_splicing(args)])
    end]
  end

  defp underscore(name) when is_atom(name) do
    underscore(Atom.to_string(name))
  end

  defp underscore(<<"_"::utf8, name::binary>>) do
    underscore(name)
  end

  defp underscore(name) do
    :"_#{name}"
  end

  defp deunderscore(name) when is_atom(name) do
    deunderscore(Atom.to_string(name))
  end

  defp deunderscore(<<"_"::utf8, name::binary>>) do
    deunderscore(name)
  end

  defp deunderscore(name) do
    String.to_atom(name) 
  end

  defp get_attribute(module, key, default \\ nil) do
    case :code.ensure_loaded(module) do
      {:module, module} ->
        module.__info__(:attributes)
        |> Keyword.get(:"$inherit", [%{}])
        |> List.first()
        |> Map.get(key, default)
      {:error, _error} ->
        Module.get_attribute(module, :"$inherit", %{})
        |> Map.get(key, default)
    end
  end

  defp put_attribute(module, key, value) do
    if !Module.has_attribute?(module, :"$inherit") do
      Module.register_attribute(module, :"$inherit", persist: true)
      Module.put_attribute(module, :"$inherit", %{})
    end

    attrs = Module.get_attribute(module, :"$inherit", %{})
    Module.put_attribute(module, :"$inherit", Map.put(attrs, key, value))
  end

  defp put_attribute_lazy(module, key, func) when is_function(func, 1) do
    attrs = get_attribute(module, key)
    put_attribute(module, key, func.(attrs))
  end

  defp parent(module) do
    get_attribute(module, :parent)
  end

  @doc false
  def debug(quoted, caller, opts \\ []) do
    body = Macro.expand(quoted, caller)

    name =
      Module.split(caller.module)
      |> List.last()

    file_name = "#{Macro.underscore(name)}.ex"

    content = if Keyword.get(opts, :quoted) do
      inspect(body, pretty: true, printable_limit: :infinity, limit: :infinity)
    else
      """
      defmodule #{name} do
        #{Macro.to_string(body)}
      end
      """
      |> Code.format_string!()
    end

    File.mkdir(".inheritdebug/")
    File.write(".inheritdebug/#{file_name}", content)

    quoted
  end

  @doc """
  Retrieves inheritance attributes for a given module.

  Returns the inheritance metadata stored in the module's `$inherit` attribute,
  which contains information about the module's inheritance hierarchy and AST data.

  ## Parameters

  - `module` - The module to retrieve inheritance attributes for

  ## Returns

  A map containing inheritance metadata including:
  - `:parent` - The parent module (if any)
  - `:ast` - Stored AST for functions
  - `:private_funcs` - Private function definitions
  - `:requires` - Required modules for imports

  ## Example

      iex> Inherit.attributes_for(MyChildModule)
      %{parent: MyParentModule, ast: [...], private_funcs: [...], requires: [...]}
  """
  def attributes_for(module) do
    module.__info__(:attributes)
    |> Keyword.get(:"$inherit")
    |> List.first()
  end

  @doc """
  Merges parent struct fields with child fields for inheritance.

  This function is used internally during the inheritance process to combine
  parent module struct fields with additional fields specified by the child module.
  Child fields take precedence over parent fields when there are conflicts.

  ## Parameters

  - `parent` - The parent module to inherit struct fields from
  - `fields` - A keyword list of additional fields to merge

  ## Returns

  A keyword list containing the merged struct fields.

  ## Example

      iex> Inherit.merge_from(ParentModule, [child_field: "value"])
      [parent_field1: "default", parent_field2: 42, child_field: "value"]

  ## Technical Notes

  This function is called automatically during inheritance setup and should not
  typically be called directly by user code.
  """
  def merge_from(parent, fields) do
    struct(parent)
    |> Map.from_struct()
    |> Map.to_list()
    |> Keyword.merge(fields)
  end
end
