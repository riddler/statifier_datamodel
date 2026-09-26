defmodule StatifierDatamodel.Schema do
  @moduledoc """
  Where the datamodel document's JSON Schema is, and what it says (ADR-0002).

  The package ships one JSON Schema, `priv/schemas/datamodel-document.schema.json`,
  written by hand against JSON Schema draft-07 from ADR-0001 and its
  amendments. It describes the well-formed version-1 document: the three
  scopes in order, an entry's four required keys, a declaration's `kind`,
  the booleans that must be booleans. A host validates a document against it
  with whatever draft-07 validator its own language has, before anything
  indexes the document.

  ## Advisory, never admission

  Nothing in this package calls either function here, and nothing validates
  a document against the file. `StatifierDatamodel.Index.index/1` stays the
  admission step and answers exactly what it answered before the file
  existed: a document the schema rejects indexes as it always did. The
  schema is deliberately stricter than `index/1`, and that gap is what a
  host checks for - a dropped scope, a `sensitive?` spelled as a string, a
  declaration whose `kind` is neither `record` nor `shape`, each of which
  indexes without a word and loses what the host meant. A rejection is a fact for the host to
  read and a severity for the host to assign, never a verdict this package
  issues.

  ## The two readers

  `path/0` answers where the file is inside the installed application, so a
  host finds it without knowing the package's install layout. `json/0`
  answers its contents, embedded at compile time so reading it touches no
  disk at run time. `json/0` answers the JSON text, not a decoded map: the
  package decodes no JSON anywhere, and a host decodes it with the decoder
  it already has.

  The file's `$id` is keyed on the document `version` it describes, not on
  the package version. A document `version` bump ships a second file beside
  this one; until then both functions answer version 1.
  """

  @relative "priv/schemas/datamodel-document.schema.json"
  @source Path.expand("../../" <> @relative, __DIR__)
  @external_resource @source
  @json File.read!(@source)

  @doc """
  The absolute path of the document's JSON Schema in the installed
  application's `priv` directory.

  ## Examples

      iex> StatifierDatamodel.Schema.path() |> Path.basename()
      "datamodel-document.schema.json"

  """
  @spec path() :: String.t()
  def path, do: Application.app_dir(:statifier_datamodel, @relative)

  @doc """
  The document's JSON Schema as JSON text, embedded at compile time.

  The text, not a decoded map; decode it with the JSON decoder the host
  already has.

  ## Examples

      iex> StatifierDatamodel.Schema.json() =~ ~s("$schema": "http://json-schema.org/draft-07/schema#")
      true

  """
  @spec json() :: String.t()
  def json, do: @json
end
