defmodule StatifierDatamodel.SchemaTest do
  @moduledoc """
  ADR-0002, asserted against the shipped file.

  The schema is validated here with `ex_json_schema`, a test-only
  dependency (decision 10); nothing in `lib/` calls it (decision 4). Every
  fixture under `test/fixtures/documents/` validates and indexes; each
  near-miss the record's worked example names is rejected by the schema and
  still indexes exactly as `StatifierDatamodel.Index.index/1` indexed it
  before the file existed; the nine spellings the file lists are pinned
  to the index's closed set (decision 2); the keys ADR-0001's Decision
  section names for each object of the document, with the two keys its
  Amendment of 2026-10-13 adds, are the keys the file lists for it; and
  ADR-0004's worked example validates once its nameless entry is gone.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Schema

  alias ExJsonSchema.Validator
  alias StatifierDatamodel.Events
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

  # The worked shape with one events entry and one sends entry, each whole.
  defp with_sections do
    Map.merge(worked(), %{
      "events" => [%{"name" => "loan.renewed", "type" => "object"}],
      "sends" => [%{"name" => "patron.due_soon", "type" => "object", "label" => "Due soon"}]
    })
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
      {"a numeric scope label", update_scope(worked, "local", &Map.put(&1, "label", 5)),
       ["#/scopes/1"], fn index -> assert index.entries == Index.index(worked).entries end},
      {"a numeric scope description",
       update_scope(worked, "event", &Map.put(&1, "description", 5)), ["#/scopes/2"],
       fn index -> assert index.entries == Index.index(worked).entries end},
      {"a numeric declaration name",
       update_declaration(worked, "Settleable", &Map.put(&1, "name", 5)), ["#/types/2/name"],
       fn index ->
         refute Map.has_key?(index.declarations, "Settleable")
         assert index.entries == Index.index(worked).entries
       end},
      {"a numeric declaration label",
       update_declaration(worked, "cards.card", &Map.put(&1, "label", 5)), ["#/types/1/label"],
       fn index ->
         assert index.declarations["cards.card"].label == nil
         assert index.entries == Index.index(worked).entries
       end},
      {"version 2", Map.put(worked, "version", 2), ["#/version"],
       fn index ->
         assert index.version == 2
         assert index.entries == Index.index(worked).entries
       end},
      {"events not a list", Map.put(with_sections(), "events", %{"loan.renewed" => "object"}),
       ["#/events"], fn index -> assert index == Index.index(worked) end},
      {"an events entry missing name",
       update_in(with_sections()["events"], &[%{"type" => "object"} | &1]), ["#/events/0"],
       fn index -> assert index == Index.index(worked) end},
      {"an empty sends name",
       update_in(with_sections()["sends"], &[%{"name" => "", "type" => "object"} | &1]),
       ["#/sends/0/name"], fn index -> assert index == Index.index(worked) end},
      {"a numeric sends type",
       update_in(with_sections()["sends"], &[%{"name" => "patron.overdue", "type" => 7} | &1]),
       ["#/sends/0/type"], fn index -> assert index == Index.index(worked) end}
    ]
  end

  describe "the near-misses" do
    # Sabotage: dropping minItems from `scopes` in the schema file turned
    # "two scopes" red; dropping the `const` of the first tuple position
    # turned "scopes out of order" red; changing `sensitive?` to
    # {"type": ["boolean", "string"]} turned "a string sensitive?" red;
    # dropping the string type of the scope's `label`, the scope's
    # `description`, the declaration's `name` or the declaration's `label`
    # turned the matching "a numeric ..." row red; dropping the minLength of
    # definitions/payload_entry's `name`, dropping `name` from its required
    # list, typing `events` as an array or an object, and dropping the
    # string type of its `type` each turned this test red; reverted each.
    test "each is rejected by the schema at the rule it breaks", %{schema: schema} do
      for {name, document, paths, _index} <- negatives() do
        assert {name, paths} == {name, error_paths(schema, document)}
      end
    end

    # Sabotage: making index/1 answer nil for a document whose version is
    # not 1 (a guard in index.ex) turned this test red at "version 2";
    # reading a declaration's label without the string check in
    # declarations.ex turned it red at "a numeric declaration label";
    # reverted each.
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

  describe "ADR-0004's worked example" do
    # The record's `## Worked example` JSON block, read from the record
    # rather than copied, so the example and the file cannot drift apart.
    @adr_0004 Path.expand("../../docs/adr/0004-event-and-send-payloads.md", __DIR__)

    defp adr_0004_example do
      [_before, after_heading] = String.split(File.read!(@adr_0004), "\n## Worked example\n")
      [_prose, after_fence] = String.split(after_heading, "```json\n", parts: 2)
      [json, _rest] = String.split(after_fence, "\n```\n", parts: 2)
      JSON.decode!(json)
    end

    # Sabotage: dropping `name` from definitions/payload_entry's required
    # list in the schema file turned this test red (the nameless entry
    # validated); typing its `label` as an integer turned it red (the whole
    # example failed); reverted each.
    test "validates without its nameless entry, is rejected with it, and indexes the same",
         %{schema: schema} do
      example = adr_0004_example()

      assert [%{"label" => "No name"} = nameless] =
               Enum.reject(example["events"], &Map.has_key?(&1, "name"))

      whole = update_in(example["events"], &List.delete(&1, nameless))

      assert Validator.validate(schema, whole) == :ok
      assert error_paths(schema, example) == ["#/events/4"]
      assert Index.index(example) == Index.index(whole)
      assert Events.from_document(example) == Events.from_document(whole)
    end
  end

  describe "the record's keys" do
    # ADR-0001 states the document's keys in its Decision section: decision
    # 3 lists the document's keys as bullets and a scope's and an entry's in
    # prose, decision 5 lists a declaration's in its one key table and a
    # field's in prose. The test reads each from the record's text, not from
    # a copy of it, so a key the record gains or loses without the schema
    # file, or the file without the record, turns it red. The record's
    # Amendment of 2026-10-13 adds two document keys as bullets in decision
    # 3's own form, and they are read from that Amendment's Decision section;
    # the keys of an `events` or `sends` entry are ADR-0004 decision 2's key
    # table, read the same way as decision 5's. A key any other amendment
    # adds outside these sections is outside this walk; ADR-0002 decision 9
    # keeps the file in step with those by review.
    @record Path.expand("../../docs/adr/0001-datamodel-document.md", __DIR__)
    @payload_record Path.expand("../../docs/adr/0004-event-and-send-payloads.md", __DIR__)

    # The heading of the Amendment that adds `events` and `sends`.
    @sections_amendment "\n## Amendment (2026-10-13): decision 3, the document gains `events` and `sends`"

    defp decision_section do
      text = File.read!(@record)
      [_context, rest] = String.split(text, "\n## Decision\n", parts: 2)
      [section, _rest] = String.split(rest, "\n## The contract as typespecs\n", parts: 2)
      section
    end

    defp between(text, from, to) do
      [_before, after_from] = String.split(text, from, parts: 2)
      [inside, _after_to] = String.split(after_from, to, parts: 2)
      inside
    end

    # The text between `from` and the first `to` after it, read with the
    # record's line breaks as spaces, with each parenthesised aside dropped.
    defp span(text, from, to) do
      text
      |> String.replace(~r/\s+/, " ")
      |> between(from, to)
      |> String.replace(~r/\([^)]*\)/, "")
    end

    defp backticked(text), do: ~r/`([^`]+)`/ |> Regex.scan(text) |> Enum.map(&List.last/1)

    # A key list the record writes as "<required keys> ... optional <keys>":
    # the keys before the first "optional" are required, the rest optional.
    defp split_optional(text) do
      [required, optional] = String.split(text, "optional", parts: 2)
      %{required: backticked(required), optional: backticked(optional)}
    end

    # The Amendment's own Decision section, up to its Consequences.
    defp amendment_decision do
      @record
      |> File.read!()
      |> between(@sections_amendment, "\n### Consequences\n")
      |> between("\n### Decision\n", "**(b)")
    end

    # Decision 3 writes each document key as a bullet that opens with the
    # key, and the optional one says so first.
    defp key_bullets(text, acc) do
      ~r/^- `([^`]+)` - (optional)?/m
      |> Regex.scan(text)
      |> Enum.reduce(acc, fn
        [_, key], acc -> Map.update!(acc, :required, &(&1 ++ [key]))
        [_, key, "optional"], acc -> Map.update!(acc, :optional, &(&1 ++ [key]))
      end)
    end

    defp record_keys do
      section = decision_section()
      shape = between(section, "**3. The shape.**", "An **entry**")

      document =
        key_bullets(amendment_decision(), key_bullets(shape, %{required: [], optional: []}))

      scope = %{required: backticked(span(shape, "A scope carries", ".")), optional: []}

      entry =
        split_optional(
          span(section, "An **entry** carries the four required keys", "with the meanings")
        )

      field = split_optional(span(section, "A **field** carries", ". A field's"))
      list_field = backticked(span(section, "A `list` field carries", "under the same rule"))

      %{
        "document" => document,
        "scope" => scope,
        "entry" => entry,
        "declaration" => key_table(section, "**5. The `types` key", "A **field** carries"),
        "field" => %{field | optional: field.optional ++ list_field},
        "payload_entry" =>
          key_table(File.read!(@payload_record), "**2. An entry: `name`", "**3. `type`")
      }
    end

    # A key table: one row per key, `| key | yes/no | ... |`, between two
    # markers - ADR-0001 decision 5's for a declaration, ADR-0004 decision
    # 2's for an entry of `events` or `sends`.
    defp key_table(text, from, to) do
      text
      |> between(from, to)
      |> String.split("\n", trim: true)
      |> Enum.filter(&String.starts_with?(&1, "| `"))
      |> Enum.reduce(%{required: [], optional: []}, fn row, acc ->
        [_, key, required | _] = row |> String.split("|") |> Enum.map(&String.trim/1)
        bucket = if required == "yes", do: :required, else: :optional
        Map.update!(acc, bucket, &(&1 ++ [String.trim(key, "`")]))
      end)
    end

    # The schema's keys per object: its `properties` and `required`. A
    # scope's `scope` key is fixed per position of the `scopes` tuple, not
    # under definitions/scope (ADR-0002's amendment of 2026-10-11), so the
    # tuple's positions are read too.
    defp schema_keys do
      schema = JSON.decode!(Schema.json())
      definitions = schema["definitions"]

      tuple_keys =
        for position <- schema["properties"]["scopes"]["items"],
            part <- position["allOf"],
            key <- Map.keys(part["properties"] || %{}),
            uniq: true,
            do: key

      object = fn definition, extra ->
        %{
          keys: MapSet.new(Map.keys(definition["properties"]) ++ extra),
          required: MapSet.new(definition["required"])
        }
      end

      %{
        "document" => object.(schema, []),
        "scope" => object.(definitions["scope"], tuple_keys),
        "entry" => object.(definitions["entry"], []),
        "declaration" => object.(definitions["declaration"], []),
        "field" => object.(definitions["field"], []),
        "payload_entry" => object.(definitions["payload_entry"], [])
      }
    end

    # Sabotage: adding an "audience" property to definitions/entry, and
    # another to definitions/declaration, in the schema file turned this test
    # red; dropping "description" from definitions/scope's required list
    # turned it red; in ADR-0001, deleting the `note` row from decision 5's
    # table, deleting `note` from decision 3's entry sentence and adding an
    # `owner` key to its scope sentence each turned it red; adding an
    # "audience" property to definitions/payload_entry turned it red, and so
    # did deleting the `sends` bullet from the Amendment of 2026-10-13;
    # reverted each.
    test "each object's keys in ADR-0001's Decision section are the schema's keys" do
      record = record_keys()
      schema = schema_keys()

      assert Map.keys(record) |> Enum.sort() == Map.keys(schema) |> Enum.sort()

      for {object, %{required: required, optional: optional}} <- record do
        refute required == [], "#{object}: no required key read from the record"

        assert {object, MapSet.new(required ++ optional), MapSet.new(required)} ==
                 {object, schema[object].keys, schema[object].required}
      end
    end
  end
end
