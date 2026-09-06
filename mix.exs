defmodule StatifierDatamodel.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/riddler/statifier_datamodel"

  def project do
    [
      app: :statifier_datamodel,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "StatifierDatamodel",
      description:
        "The datamodel document and what can be decided from it: the typed three-scope declaration, its named record and shape types, the path/type index, the read check, compatibility and coverage - pure functions, no dependency on the block editor, the compiler or the UI",
      source_url: @source_url,
      docs: docs(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:ex_unit]],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Hexdocs configuration. These paths are read off the publisher's disk at
  # `mix docs` time and need no entry in package()'s files: list - the docs
  # tarball hexdocs hosts is built separately from the package tarball
  # `mix deps.get` fetches.
  defp docs do
    [
      name: "StatifierDatamodel",
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/statifier_datamodel",
      source_url: @source_url,
      main: "readme",
      # The ADRs ship as extras because this package is small enough that its
      # records ARE its reference: a reader deciding whether a document is
      # admitted, or why a record read as a shape is, reads the record. The
      # glob takes the numbered records and not `docs/adr/README.md`, whose
      # page id would collide with the front page's.
      extras: ["README.md", "CHANGELOG.md"] ++ Path.wildcard("docs/adr/0*.md"),
      groups_for_extras: [
        "Architecture decisions": ~r{docs/adr/}
      ],
      # The groups follow the package's own seams so the sidebar reads as the
      # architecture rather than as the alphabet: the document and its index,
      # the declared types and the read check, and what is decided across two
      # declarations or between a declaration and a value. Order matters:
      # ex_doc assigns each module to the first group whose pattern matches.
      # `StatifierDatamodel` itself matches none of them on purpose - the root
      # module is the package's own overview and belongs above the seams, not
      # inside one of them.
      groups_for_modules: [
        "Document and index": [
          ~r/^StatifierDatamodel\.(Document|Index)($|\.)/
        ],
        "Declared types": [
          ~r/^StatifierDatamodel\.(Types|Declarations)($|\.)/
        ],
        "Compatibility and coverage": [
          ~r/^StatifierDatamodel\.(Compatibility|Coverage)($|\.)/
        ]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp package do
    [
      name: "statifier_datamodel",
      licenses: ["MIT"],
      files: ~w(lib mix.exs .formatter.exs README.md LICENSE CHANGELOG.md),
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  # No runtime dependencies, and none in the family. The two statifier_blocks
  # modules this package re-homes - the document index and the pure half of
  # the datamodel reader - normalize a decoded map and call nothing in
  # predicator or statifier; that was checked before this list was written,
  # and it is the property that lets both statifier_blocks and statifier_ui
  # take this package without either taking the other. A runtime dependency
  # added here is a decision to record, not a convenience to reach for.
  defp deps do
    [
      # Dev / test
      {:ex_quality, "~> 0.14", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end
end
