defmodule InheritTest do
  use ExUnit.Case

  test "Foo" do
    assert %Foo{}.a == 1
  end

  test "Bar inherits fields and public functions from Foo" do
    %Bar{} = bar = %Bar{}
    assert Bar.add(bar.a, bar.b) == 3
  end
  #
  test "Baz inherits from Foo" do
    %Baz{} = baz = %Baz{}
    assert Baz.add(baz.a, baz.b) == 4
  end

  test "Qux inherits from Foo" do
    %Qux{} = qux = %Qux{}
    assert Qux.add(qux.a, qux.b) == 4
  end

  test "can override __using__" do
    assert Bar.used?
    refute Baz.used?()
  end

  test "0 arity functions supported" do
    assert Baz.allowed() == [z: 1, y: 2]
  end

  test "overridden __using__ is inherited with proper module scope" do
    assert Qux.module() == Qux
    assert Baz.module() == Baz
    assert Bar.module() == Bar
  end

  test "properly implements ineritance order of functions" do
    assert Qux.incr(1) == 5
  end
end
