defmodule StatifierDatamodel.Coverage do
  @moduledoc """
  ADR-0001 decision 10: which required fields of a shape a map does not fill.

  `missing/3` is given the declarations, the name of a shape and a map, and
  answers `{:ok, names}` - the `name` of every required field of that shape
  the map does not fill, in declaration order - or `:error`.

  ## Only a shape has coverage

  A shape is the constraint a read places on a path, so *does this map cover
  it* is a question a shape has an answer to. A record is a fact about what a
  write puts somewhere, and an undeclared name is nothing at all; neither is
  a shape, and both are `:error` rather than `{:ok, []}`. Answering *nothing
  is missing* for a name that declares no requirements would read as coverage
  achieved, which is the one wrong answer here.

  ## Fill is presence with a value

  A field is filled when the map carries its `name` as a key with a
  non-`nil` value. The value's type is not checked against the field's: a map
  here is data a host handed in, and the type of a value is the expression
  language's question, not the document's. A key spelled as an atom is not
  the field's key - a document's names are strings, and the map is read with
  the string it declares.

  The order is the shape's own field order, so a pane may render the answer
  as the shape reads. Nothing raises: an input that is not a map fills
  nothing, and every required field of the shape is named.
  """

  alias StatifierDatamodel.Declarations

  @doc """
  The required field names of the shape `name` that `map` does not fill.

      iex> alias StatifierDatamodel.{Coverage, Declarations}
      iex> declarations = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "Settleable", "kind" => "shape", "label" => "Settleable", "fields" => [
      ...>     %{"name" => "amount_cents", "type" => "integer", "required?" => true},
      ...>     %{"name" => "currency", "type" => "string", "required?" => true},
      ...>     %{"name" => "note", "type" => "string"}]},
      ...>   %{"name" => "cards.card", "kind" => "record", "label" => "Card", "fields" => []}]})
      iex> Coverage.missing(declarations, "Settleable", %{"amount_cents" => 1250, "currency" => "USD"})
      {:ok, []}
      iex> Coverage.missing(declarations, "Settleable", %{"currency" => nil})
      {:ok, ["amount_cents", "currency"]}
      iex> Coverage.missing(declarations, "cards.card", %{})
      :error
      iex> Coverage.missing(declarations, "Refundable", %{})
      :error
  """
  @spec missing(Declarations.t(), term(), term()) :: {:ok, [String.t()]} | :error
  def missing(declarations, name, map) do
    case Declarations.fetch(declarations, name) do
      {:ok, %{kind: :shape, fields: fields}} ->
        {:ok, for(field <- fields, field.required?, not filled?(map, field.name), do: field.name)}

      _a_record_or_no_such_name ->
        :error
    end
  end

  @spec filled?(term(), String.t()) :: boolean()
  defp filled?(map, name) when is_map(map), do: Map.get(map, name) != nil
  defp filled?(_not_a_map, _name), do: false
end
