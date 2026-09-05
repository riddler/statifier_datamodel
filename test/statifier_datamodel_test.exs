defmodule StatifierDatamodelTest do
  use ExUnit.Case, async: true

  doctest StatifierDatamodel

  test "the package scaffold compiles and the root module is loadable" do
    assert Code.ensure_loaded?(StatifierDatamodel)
  end
end
