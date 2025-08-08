defmodule Qux do
  use Baz, [
    a: 2,
    c: 4
  ]

  # this function  will never 
  # be hit because Baz.incr/1
  # doesn't set itself
  # as overridable
  # This emits a warning in
  # the test suite on purposes
  # so we can assert that the priority
  # is correct
  def incr(val) do
    parent().incr(val) + 1
  end

  def encode(qux) do
    Map.merge(super(qux), %{qux: 1})
  end
  defoverridable encode: 1

  def module do
    Atom.to_string(__MODULE__)
  end
end

