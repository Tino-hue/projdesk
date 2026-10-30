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

### Changed

- The kernel now requires **MoonBit 0.1.20261023 or newer**, which is the
  release that spells the 32-bit integer `Int32` the way the `moonmodel`
  package is published. The compatibility patch that adjusted the dependency
  at build time is gone: the dependency is used exactly as published.
- The kernel is published to Mooncakes as `Tino-hue/projdesk-kernel`.

### Fixed

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
