defmodule InheritTest do
  use ExUnit.Case

  test "Foo" do
    assert %Foo{}.a == 1
  end

  test "Bar inherits fields and public functions from Foo" do
    %Bar{} = bar = %Bar{}
    assert Bar.add(bar.a, bar.b) == 3
  end

  test "Baz inherits from Foo" do
    %Baz{} = baz = %Baz{}
    assert Baz.add(baz.a, baz.b) == 4
  end

  test "Qux inherits from Foo" do
    %Qux{} = qux = %Qux{}
    assert Qux.add(qux.a, qux.b) == 5
  end

  test "can override __using__" do
    assert Bar.used?
    refute Baz.used?()
  end

  test "0 arity functions supported" do
    assert Baz.allowed() == [z: 1, y: 2]
  end

  test "overridden __using__ is inherited with proper module scope" do
    assert Baz.module() == Baz
    assert Bar.module() == Bar
    assert Qux.module() =~ "Qux"
  end

  test "properly implements ineritance order of functions" do
    assert Qux.incr(1) == 4
  end

  test "Empty is empty" do
    %Empty{} = _empty = %Empty{}
  end

  test "can inherit from an empty parent" do
    %Other{} = _other = %Other{}
  end

  test "inherited fields should not escaped macros" do
    bar = %Bar{}
    assert [] == bar.list
    assert 1 == bar.a
    assert %{} == bar.assigns
    assert 2 == bar.b
    assert %{a: 1, b: {:a, [], [1, 2]}} == bar.c
  end
end
