defmodule StatifierDatamodel.READMETest do
  @moduledoc """
  The README's basic-usage example is a doctest, not prose.

  The front page is the first code a reader of this package sees, so an
  example that stops being true has to fail the suite rather than sit there
  being wrong on hexdocs. `doctest_file/1` runs every `iex>` block in the
  file; the installation snippet carries no prompt and is not one.
  """

  use ExUnit.Case, async: true

  # Sabotage: changing an expected value in README.md's index example (the
  # `index.order` list) turned this file red with one failure naming the
  # README line; reverted.
  doctest_file("README.md")
end
