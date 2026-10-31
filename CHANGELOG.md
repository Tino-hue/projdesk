# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

The MoonBit kernel (`moonbit/`) is published separately as
`Tino-hue/projdesk-kernel`; its public API is listed in
`moonbit/main/pkg.generated.mbti`.

## [Unreleased]

### Added

- `projdesk contrast <model.dsl>` prints what the constraint solver finds
  next to what the projection carries through in silence.
- The kernel resolves cross-field constraint references symbolically: a bound
  may take its value from another field's bound, may point forward or
  backward, and a cycle of references is reported rather than ignored.
- The round-trip verifier compares every field, type and constraint instead of
  field names and four flags.
- All seven projection targets report a typed drop report, and the TypeScript,
  Zod and Prisma emitters implement the `Projector` trait.
- The CI runs the kernel's own test suite (`moon check` and `moon test`).
- The README carries a "Verify the claims" section: every claim points at the
  code and the command that shows it.
- `scripts/verify-registry-consumption.js` resolves the published kernel from
  Mooncakes, compiles a throwaway consumer module against it, runs it and fails
  unless all seven projections come out. The CI runs it, so "a third party can
  consume this" is a check rather than a claim.
- A failed round-trip is now typed instead of prose. `RoundTripError` is a
  MoonBit error type with one variant per way a round-trip can fail — a lex
  error, a parse error, a changed model count, a mismatching model, a type the
  DSL cannot express, no models at all — and each one says whether the source
  that was handed in or the source the printer produced is the one that broke.
  The ABI adds `reason` and `stage` beside the existing `ok` and `message`.
- `examples/Unprintable.dsl` is a model the printer cannot reproduce, so the
  typed failure can be seen from the command line.
- `examples/CrossFieldConflict.dsl` is a model whose contradiction only
  appears once a cross-field reference is resolved: `low`'s own bound is
  satisfiable on its own, and `high` borrows it. It is the sharpest
  illustration of what a per-field validator cannot see.
- **A schema solvability checker** — the sixth engine. It reads a JSON Schema
  and answers the question no schema library in the ecosystem answers: does
  *any* value satisfy it? Interval algebra over `allOf`, `anyOf`, `oneOf`,
  `not` and `$ref`; numeric bounds, string lengths and array item counts each
  checked against the others; enums checked against the bounds around them;
  dangling references; a `multipleOf` that is not positive. Findings carry a
  JSON Pointer.
  `node cli/index.js check-schema <file.json>` and the twelfth ABI export,
  `check_schema_satisfiability`, both use it. `check-schema -` reads the
  schema from stdin, so a projection can be piped into it.
  `examples/moon_zod_dead_schema.json` is byte for byte what `moon_zod` 0.9.2
  exported from `number().min(10).max(5)`, `string().min(5).max(2)` and
  `array().min(5).max(2)` — a schema that no value can satisfy, which
  `moon_zod` itself accepts silently and then rejects every value of. The
  checker names it instead.

### Changed

- The kernel serializes to JSON with the language's `derive(ToJson)` wherever
  the shape is a fixed record. The wire shapes are now declared once, as
  types, instead of being assembled key by key: 138 hand-written
  `Json::` builder calls became 59, and every `Json::number` call is gone —
  the number and boolean formatting is the language's now. What is left is
  what a derive cannot express: leaf values (`Json::string` for a default or
  an option set) and the one genuinely heterogeneous shape, a type that is
  either a name, a list, a dict, a reference, a nested model or raw JSON.
- The README, the proposal and the submission text now state the boundary
  against the existing MoonBit ecosystem explicitly — which library covers
  which part, where the overlap really is (three emitters), and which three
  questions this project answers that the ecosystem does not. The custom
  notation is justified by exactly one capability: a constraint that
  references another field's constraint, which the schema data model has
  nowhere to put.

### Changed

- The kernel now requires **MoonBit 0.1.20261023 or newer**, which is the
  release that spells the 32-bit integer `Int32` the way the `moonmodel`
  package is published. The compatibility patch that adjusted the dependency
  at build time is gone: the dependency is used exactly as published.
- The kernel is published to Mooncakes as `Tino-hue/projdesk-kernel`.
- `RoundTrip::Fail` carries a `RoundTripError` instead of a `String`, so the
  kernel's public API changed and the published package moves to **0.2.0**.
  0.1.0 stays as it was published.

### Added

- `scripts/audit-claims.js` checks every number the documents state against
  the code: the line counts per engine, the implementation and test totals, the
  export count, and the test counts. The test counts are read from the source
  rather than remembered — `it.each(table)` expands into one case per row, so
  counting the calls alone would undercount. `make audit` runs it, and it is
  part of `make all`, so a number that drifts is caught instead of shipped.

### Removed

- `PROPOSAL.md`, which had become byte-identical to `SUBMISSION-TEXT.md` down
  to the title, and the script that kept the two in step. One declaration is
  easier to keep right than two.
- `cli/example.dsl` and `cli/example-model.json`: nothing referred to them,
  and `models/` already holds four documented models.
- `examples/ContradictorySchema.json`: the artifact `moon_zod` produced
  covers the same kinds of contradiction, with a third party as the author.

### Added

- **The migration engine now judges constraints by meaning, not by text.**
  A schema diff compares the text of the constraints, which cannot answer two
  questions that matter: whether a constraint change changes anything at all,
  and whether it leaves the field with no satisfying value.
  - A constraint another constraint already implies — `least=0` where `over=0`
    exists — is reported as **redundant** and is **not** breaking, because the
    field accepts the same values before and after.
  - A change that leaves the field with **no satisfying value** is reported as
    such, with the solver's own diagnosis, instead of as a constraint swap.
  - A bound that moved is **one** change with a direction, so widening an
    upper bound is no longer counted as breaking. It was.
  - A constraint set that differs only in the values of its enum was not
    detected at all before, because only the number of options was compared.
    It is now, and the diff says which values changed.
- **A reusable GitHub Action**, `.github/actions/check-schema`, so a project
  can fail its build when a JSON Schema has no satisfying value:

  ```yaml
  - uses: Tino-hue/projdesk/.github/actions/check-schema@main
    with:
      schema: openapi/schema.json
  ```

  It needs nothing but Node — the kernel is committed to the repository.

### Fixed

- `projdesk check` on a JSON Schema reported nothing at all: it handed the
  schema to the model solver, which found no fields in it, and said the schema
  was fine. It now recognises a schema and checks it with the solvability
  engine, and says why the model-level engines need the DSL.
- `examples/moon_zod_dead_schema.json` carried a byte-order mark, so it was not
  what `moon_zod` produced and a strict JSON parser rejected it. It is now
  moon_zod's raw output, byte for byte.
- The registry consumption check read "the registry could not be reached" as
  "this version is not published yet", so an outage turned the check into a
  silent skip. It now tells the three outcomes apart — published, missing
  (the registry answered), and unreachable (the registry did not answer) —
  and fails loudly on the last one instead of skipping.
- The README's consumer example printed the result tuple, which the compiler
  reports as a deprecated `Show`; it now prints the projections and the
  problems separately, and the CI check fails on any warning.
- The round-trip verifier reported models as sound while losing their
  constraints, and reported a field reached from two places as a cycle.
- `projdesk migrate` answered "0 changes" for DSL sources instead of failing,
  and could not be given a model to compare at all.
- The setup scripts stopped at their first step on a machine that had never
  built the project.

## [0.1.0] - 2026-10-28

The first public release.

- Five independent MoonBit engines over one model description: a DSL compiler
  (lexer, recursive descent parser, constraint expressions, AST codegen, AST
  printer, semantic checks), a constraint solver (conflict, redundancy and
  containment analysis, interval propagation), a migration engine
  (structured diff, SQL generation, breaking-change classification), an
  equivalence checker (type widening, constraint containment) and a round-trip
  verifier.
- Projection to JSON Schema, OpenAPI, SQL DDL, GraphQL SDL, TypeScript, Zod and
  Prisma, with a typed drop report for every constraint a target cannot carry.
- A browser workbench: model editor, relation graph, constraint coverage
  matrix, version diff, and an engine playground.
- A command-line tool, a VS Code extension, and a Cloudflare Workers backend.
