defmodule StatifierDatamodel.SchemaTest do
  @moduledoc """
  ADR-0002, asserted against the shipped file.

  The schema is validated here with `ex_json_schema`, a test-only
  dependency (decision 10); nothing in `lib/` calls it (decision 4). Every
  fixture under `test/fixtures/documents/` validates and indexes; each
  near-miss the record's worked example names is rejected by the schema and
  still indexes exactly as `StatifierDatamodel.Index.index/1` indexed it
  before the file existed; and the nine spellings the file lists are pinned
  to the index's closed set (decision 2).
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Schema

  alias ExJsonSchema.Validator
  alias StatifierDatamodel.Index
  alias StatifierDatamodel.Schema

  @fixtures Path.expand("../fixtures/documents", __DIR__)

  # The reference host's card-processing document, copied from
  # riddler/statifier_examples `priv/fixtures/card-processing.datamodel.json`
  # at commit fed826ca9d0fed20e1c6152a528a0f2885d3d2fd. The one edit is a
  # `description` on each of its three scopes, which the source omits and
  # ADR-0001 decision 3 has a scope carry; the test below proves the edit
  # changes nothing `index/1` answers.
  @host_copy "statifier_examples-card-processing.datamodel.json"

  # ADR-0001's `## Worked shape` JSON block, extracted verbatim.
  @worked "adr-0001-worked-shape.json"

  @nine ~w(string integer decimal boolean datetime duration date object list)

  # ADR-0001's worked shape: "exactly ... nine paths, and nothing from
  # `types`".
  @worked_paths ~w(limits limits.authorization_window amount_cents risk_reasons card
                   card.brand card.last4 card.expires_on event.name)

  setup_all do
    %{schema: Schema.json() |> JSON.decode!() |> ExJsonSchema.Schema.resolve()}
  end

  defp fixture(name), do: @fixtures |> Path.join(name) |> File.read!() |> JSON.decode!()

  defp worked, do: fixture(@worked)

  defp error_paths(schema, document) do
    case Validator.validate(schema, document) do
      :ok -> []
      {:error, errors} -> errors |> Enum.map(fn {_message, path} -> path end) |> Enum.sort()
    end
  end

  # Replace the element of `list` whose `key` is `value` with `fun.(element)`.
  defp update_where(list, key, value, fun) do
    Enum.map(list, fn
      %{^key => ^value} = element -> fun.(element)
      element -> element
    end)
  end

  defp update_scope(document, scope, fun) do
    Map.update!(document, "scopes", &update_where(&1, "scope", scope, fun))
  end

  defp update_entry(entries, path, fun) do
    Enum.map(entries, fn
      %{"path" => ^path} = entry ->
        fun.(entry)

      %{"fields" => fields} = entry when is_list(fields) ->
        %{entry | "fields" => update_entry(fields, path, fun)}

      entry ->
        entry
    end)
  end

  defp update_declaration(document, name, fun) do
    Map.update!(document, "types", &update_where(&1, "name", name, fun))
  end

  describe "the reader" do
    # Sabotage: pointing path/0 at "priv/schemas/datamodel.schema.json" in
    # schema.ex turned this test red (File.read!/1 raised enoent); reverted.
    test "path/0 names the shipped file and json/0 is its contents" do
      assert Path.type(Schema.path()) == :absolute
      assert File.read!(Schema.path()) == Schema.json()
    end

    # Sabotage: changing the file's `$id` to end in v2.schema.json turned
    # this test red; reverted.
    test "the file is draft-07 and its $id is keyed on document version 1" do
      assert %{
               "$schema" => "http://json-schema.org/draft-07/schema#",
               "$id" =>
                 "https://github.com/riddler/statifier_datamodel/schemas/datamodel-document/v1.schema.json"
             } = JSON.decode!(Schema.json())
    end

    # Sabotage: removing `priv/schemas` from package/0's files: list in
    # mix.exs turned this test red; reverted.
    test "the built package's file list includes the schema file" do
      files =
        Mix.Project.config()
        |> Keyword.fetch!(:package)
        |> Keyword.fetch!(:files)
        |> Enum.flat_map(&expand_package_path/1)

      assert "priv/schemas/datamodel-document.schema.json" in files
    end
  end

  # Hex expands each files: entry as a wildcard relative to the project root
  # and takes every file under a directory it matches.
  defp expand_package_path(entry) do
    root = File.cwd!()

    root
    |> Path.join(entry)
    |> Path.wildcard(match_dot: true)
    |> Enum.flat_map(fn path ->
      if File.dir?(path), do: Path.wildcard(Path.join(path, "**"), match_dot: true), else: [path]
    end)
    |> Enum.reject(&File.dir?/1)
    |> Enum.map(&Path.relative_to(&1, root))
  end

  describe "the fixture documents" do
    # Sabotage: adding "note" to the scope definition's required list in the
    # schema file turned this test red for both fixtures; reverted.
    test "every document under test/fixtures/documents/ validates and indexes", %{schema: schema} do
      names =
        @fixtures |> File.ls!() |> Enum.filter(&String.ends_with?(&1, ".json")) |> Enum.sort()

      assert names == [@worked, @host_copy]

      for name <- names do
        document = fixture(name)
        assert {name, :ok} == {name, Validator.validate(schema, document)}
        assert %Index{} = Index.index(document)
      end
    end

    # Sabotage: dropping "description" from the scope definition's required
    # list in the schema file turned this test red (the source validated);
    # reverted.
    test "without its added scope descriptions the host copy fails at each scope and indexes the same",
         %{schema: schema} do
      copy = fixture(@host_copy)

      source =
        Map.update!(copy, "scopes", fn scopes ->
          Enum.map(scopes, &Map.delete(&1, "description"))
        end)

      assert error_paths(schema, source) == ["#/scopes/0", "#/scopes/1", "#/scopes/2"]
      assert Index.index(source) == Index.index(copy)
    end
  end

  # ADR-0002's worked example and the bead's list: one near-miss per rule the
  # schema states and the index does not enforce. Each carries the error
  # path the schema reports and, where the document is still a map with a
  # list under "scopes", what index/1 answers for it today.
  defp negatives do
    worked = worked()
    nine = MapSet.new(@worked_paths)

    [
      {"scopes missing", Map.delete(worked, "scopes"), ["#"], nil},
      {"two scopes", update_in(worked["scopes"], &Enum.take(&1, 2)), ["#/scopes"],
       fn index -> assert Index.declared_paths(index) == MapSet.delete(nine, "event.name") end},
      {"scopes out of order",
       update_in(worked["scopes"], fn [global, local, event] -> [local, global, event] end),
       ["#/scopes/0", "#/scopes/1"],
       fn index -> assert index.entries == Index.index(worked).entries end},
      {"an entry missing path",
       update_scope(worked, "local", fn scope ->
         Map.update!(
           scope,
           "entries",
           &update_entry(&1, "amount_cents", fn e -> Map.delete(e, "path") end)
         )
       end), ["#/scopes/1"],
       fn index -> assert Index.declared_paths(index) == MapSet.delete(nine, "amount_cents") end},
      {"a string sensitive?",
       update_scope(worked, "local", fn scope ->
         Map.update!(
           scope,
           "entries",
           &update_entry(&1, "card.last4", fn e -> Map.put(e, "sensitive?", "true") end)
         )
       end), ["#/scopes/1"],
       fn index ->
         assert Index.declared_paths(index) == nine
         assert Index.sensitive_paths(index) == MapSet.new()
       end},
      {"a declaration kind neither record nor shape",
       update_declaration(worked, "Settleable", &Map.put(&1, "kind", "shap")), ["#/types/2/kind"],
       fn index ->
         refute Map.has_key?(index.declarations, "Settleable")
         assert index.entries == Index.index(worked).entries
       end},
      {"a declaration missing fields",
       update_declaration(worked, "Refundable", &Map.delete(&1, "fields")), ["#/types/3"],
       fn index ->
         refute Map.has_key?(index.declarations, "Refundable")
         assert index.entries == Index.index(worked).entries
       end},
      {"a string required?",
       update_declaration(worked, "cards.card", fn declaration ->
         Map.update!(
           declaration,
           "fields",
           &update_where(&1, "name", "last4", fn f -> Map.put(f, "required?", "true") end)
         )
       end), ["#/types/1/fields/1/required?"],
       fn index ->
         assert [%{required?: false}] =
                  Enum.filter(index.declarations["cards.card"].fields, &(&1.name == "last4"))
       end},
      {"version 2", Map.put(worked, "version", 2), ["#/version"],
       fn index ->
         assert index.version == 2
         assert index.entries == Index.index(worked).entries
       end}
    ]
  end

  describe "the near-misses" do
    # Sabotage: dropping minItems from `scopes` in the schema file turned
    # "two scopes" red; dropping the `const` of the first tuple position
    # turned "scopes out of order" red; changing `sensitive?` to
    # {"type": ["boolean", "string"]} turned "a string sensitive?" red;
    # reverted each.
    test "each is rejected by the schema at the rule it breaks", %{schema: schema} do
      for {name, document, paths, _index} <- negatives() do
        assert {name, paths} == {name, error_paths(schema, document)}
      end
    end

    # Sabotage: making index/1 answer nil for a document whose version is
    # not 1 (a guard in index.ex) turned this test red at "version 2";
    # reverted.
    test "every one that is a map with a list under scopes indexes exactly as before" do
      advisory =
        Enum.filter(negatives(), fn {_name, document, _paths, _index} ->
          match?(%{"scopes" => scopes} when is_list(scopes), document)
        end)

      assert length(advisory) == length(negatives()) - 1

      for {name, document, _paths, check} <- advisory do
        index = Index.index(document)
        assert %Index{} = index, "#{name} did not index"
        check.(index)
      end
    end

    # Sabotage: making index/1's fallback clause answer an empty index
    # instead of nil turned this test red; reverted.
    test "the one that is not a map with a list under scopes is not a document" do
      assert [{"scopes missing", document, _paths, nil}] =
               Enum.filter(negatives(), fn {_name, _document, _paths, check} -> is_nil(check) end)

      assert Index.index(document) == nil
    end
  end

  describe "the nine spellings" do
    defp one_entry(type) do
      %{
        "version" => 1,
        "scopes" => [
          %{"scope" => "global", "label" => "Global", "description" => "", "entries" => []},
          %{
            "scope" => "local",
            "label" => "Chart-local",
            "description" => "",
            "entries" => [%{"name" => "x", "path" => "x", "type" => type, "label" => "X"}]
          },
          %{"scope" => "event", "label" => "Event payload", "description" => "", "entries" => []}
        ]
      }
    end

    # Sabotage: adding "float" to the closed_type enum in the schema file
    # turned this test red (the listed set grew past the nine and "float"
    # indexed to nil); removing "date" from index.ex's @types turned it red
    # (the listed "date" indexed to nil); reverted each.
    test "each spelling the schema lists indexes to a type; one outside them does not",
         %{schema: schema} do
      listed = JSON.decode!(Schema.json())["definitions"]["closed_type"]["enum"]

      assert Enum.sort(listed) == Enum.sort(@nine)

      for spelling <- listed do
        document = one_entry(spelling)
        assert {spelling, :ok} == {spelling, Validator.validate(schema, document)}
        refute {spelling, nil} == {spelling, document |> Index.index() |> Index.type("x")}
      end

      assert one_entry("float") |> Index.index() |> Index.type("x") == nil
    end

    # Sabotage: typing an entry's `type` as {"$ref": "#/definitions/closed_type"}
    # in the schema file turned this test red; reverted.
    test "an entry whose type names a declaration validates", %{schema: schema} do
      document =
        "cards.credit_txn"
        |> one_entry()
        |> Map.put("types", [
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "label" => "Credit transaction",
            "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]
          }
        ])

      assert Validator.validate(schema, document) == :ok
      assert document |> Index.index() |> Index.type("x") == {:declared, "cards.credit_txn"}
    end
  end
end
