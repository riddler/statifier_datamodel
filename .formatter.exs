# Used by "mix format"
#
# No import_deps and no plugins: this package has no runtime dependencies and
# renders nothing, so there is no HEEx to format and no dependency whose
# locals need their parens kept off.
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
