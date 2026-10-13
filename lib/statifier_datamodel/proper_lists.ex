defmodule StatifierDatamodel.ProperLists do
  @moduledoc false

  # An improper list, `[1 | 2]`, is a term no JSON decoder produces. The
  # readers that promise totality over any input read one as a value that
  # is not a list, as `StatifierDatamodel.Conformance` does: these two
  # helpers are how they do it without changing a reader that walks a list.

  @doc false
  @spec list?(term()) :: boolean()
  def list?(value), do: is_list(value) and not List.improper?(value)

  # The document with every improper list in it, at any depth, replaced by
  # `nil`: what each reader answers for a value that is not a list. A
  # document holding no improper list comes back unchanged. Plain maps and
  # proper lists are descended; a struct is a value and is left as it is.
  @doc false
  @spec document(term()) :: term()
  def document(%{__struct__: _} = struct), do: struct

  def document(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, document(value)} end)
  end

  def document(list) when is_list(list) do
    if List.improper?(list), do: nil, else: Enum.map(list, &document/1)
  end

  def document(value), do: value
end
