# ProjDesk — Model Engineering Workbench

**Live Demo**: https://tino-hue.github.io/projdesk/

A pure-browser workbench for the full lifecycle of a data model: **define → analyze → evolve → compare → verify**, with projection to JSON Schema / OpenAPI / SQL / GraphQL / TypeScript / Zod / Prisma as one of its outputs.

**Core value**: Five independent MoonBit algorithm engines that manage a model's lifecycle. Projection is delegated to [moonbitstack/moonmodel](https://mooncakes.io/packages/moonbitstack/moonmodel) — one step in the pipeline, not the product.

---

## Core Job

> "Manage a data model like you manage code: define it in a language, analyze its constraints, evolve it safely with migrations, compare versions for equivalence, and verify it round-trips — then project it wherever you need it."

---

## Five Independent MoonBit Engines

| # | Engine | Source | Lines | What it does |
|---|--------|--------|-------|--------------|
| 1 | **DSL Compiler** | `dsl_lexer.mbt` `dsl_parser.mbt` `dsl_expr.mbt` `dsl_codegen.mbt` `dsl_printer.mbt` `dsl_semantic.mbt` `dsl_resolve.mbt` | 2114 | Hand-written lexer + recursive descent parser + constraint-expression evaluator + AST codegen + inverse AST printer + semantic checks |
| 2 | **Constraint Solver** | `solver.mbt` `solver_propagate.mbt` | 568 | Conflict / redundancy / containment analysis, cross-field bound resolution, fixed-point interval propagation, reference-cycle detection |
| 3 | **Migration Engine** | `migration.mbt` | 349 | Structured model diff + SQL `ALTER TABLE` + breaking-change detection |
| 4 | **Equivalence Checker** | `equiv.mbt` | 224 | Type subtyping + constraint containment + classification |
| 5 | **Round-trip Verifier** | `roundtrip.mbt` | 353 | Source-level generate-parse-compare, comparing every field, type and constraint |
| | **Five engines** | | **3608** | |

On top of the engines the kernel carries **1886 lines** of supporting infrastructure and property-test machinery (`projector.mbt` `codegen.mbt` `import.mbt` `project.mbt` `presets.mbt` `abi.mbt` `api.mbt` `property.mbt`) — **5494 lines** of MoonBit implementation, plus **2920 lines** of test code.

**237 MoonBit tests** (16 property-based — 12 invariants asserted over 100+ random models, plus 4 PRNG properties — and 7 performance benchmarks) + **94 frontend tests** (25 load the real WASM kernel end-to-end, and 4 render the workbench to assert that all seven projection panels appear).

---

## The Modeling Language

```model
model User {
  id: Big @unique                     // record-level uniqueness
  name: Text [shortest=1, longest=64] // length bounds
  email: Text [format=email]          // named format
  age: Int @optional [least=0, under=150]
  tags: List(Text) @optional @distinct
  home: Ref(Address)                  // reference to another model
  score: Int [least=min(5,10), most=10*3] // constraint expressions, evaluated at compile time
  tier: Text [options=[bronze, silver, gold]]
}

model Address {
  line: Text
  country: Text [shortest=2, longest=2]
}
```

**Syntax reference**

| Construct | Meaning |
|-----------|---------|
| `name: Type` | Field with a type |
| `Type` | `Bool` `Int` `Big` `Real` `Text` `Bytes` `Stamp` `Any` |
| `List(T)` / `Dict(T)` | Collection types |
| `Ref(Model)` | Reference to another model |
| `Nest { ... }` | Inline nested model |
| `@optional` | Field not required |
| `@nullable` | Field may be null |
| `@unique` | Record-level unique constraint |
| `@distinct` | List items must differ |
| `[constraint=value]` | `least` `most` `over` `under` `step` `shortest` `longest` `pattern` `format` `options=[a,b]` |
| `value` as an expression | Arithmetic `+ - * / %`, parentheses, `min` `max` `abs` `ceil` `floor` — resolved at compile time |
| `other_field.constraint` | Cross-field reference to another field's bound, e.g. `b: Int [over=a.least]` — may point forward or backward, and is resolved after the whole model is parsed |
| `// comment` | Line comment (ignored by the parser) |
| `/* comment */` | Block comment (ignored by the parser) |

Parse errors carry a line and column, and the parser recovers to continue with the next model.

---

## Engine Usage

All five engines — plus the semantic checker — are exposed through the WASM ABI (**10 exports**) and are runnable in the browser via the **Engine Playground** panel (6 tabs: DSL Compiler, Constraint Solver, Migration, Equivalence, Round-trip, Semantic Check):

| ABI export | Input | Output |
|------------|-------|--------|
| `dsl_project(dsl)` | DSL source | Seven projections as JSON |
| `solve_constraints(model_json)` | Model JSON | Diagnosis list (conflict / redundant / warning) |
| `generate_migration(old_json, new_json)` | Two model JSONs | Change list + SQL migration + breaking count |
| `check_equivalence(a_json, b_json)` | Two model JSONs | Equivalent / SubtypeOf / SupertypeOf / Incompatible |
| `verify_roundtrip(model_json)` | Model JSON | Pass / Fail + message |
| `verify_roundtrip_dsl(dsl)` | DSL source | Pass / Fail + message |
| `check_semantics(dsl)` | DSL source | Unresolved references, self-references, cycles |
| `project_from_json(model_json)` | Model JSON | Seven projections + drop reasons |
| `import_from_json_schema_str(schema)` | JSON Schema text | Model JSON (reverse import) |
| `get_presets_json()` | — | Preset models |

---

## Relationship with moonmodel

| Capability | Implemented by |
|------------|----------------|
| Model data structures (Model/Field/Check) | moonmodel (like a compiler's AST definition) |
| Seven projection format conversions | moonmodel (like a compiler's backend) |
| **DSL lexer + parser + AST codegen** | **this project** |
| **Constraint conflict / redundancy / cross-field reasoning** | **this project** |
| **Structured model diff + migration generation** | **this project** |
| **Type subtyping + equivalence classification** | **this project** |
| **Round-trip formal verification** | **this project** |

The five engines cover what a projection library cannot: they reason *about* the model rather than merely reformat it. Together they form a complete workflow — write DSL, solve constraints, evolve with migrations, compare versions, verify correctness, then project.

## Projection (delegated to moonmodel)

After lifecycle management, the model projects to seven targets:

JSON Schema 2020-12 · OpenAPI 3.0/3.1/2.0 · SQL DDL (Postgres/SQLite/MySQL) · GraphQL SDL · TypeScript · Zod · Prisma

Honest projection is preserved: every constraint a target cannot carry is reported as **dropped + reason** rather than silently discarded — all seven targets produce a typed drop report, and the Zod emitter carries the constraints Zod can express (length bounds, numeric bounds, patterns, named formats, closed value sets, list distinctness).

---

## Repository Layout

```
moonbit/                 MoonBit kernel (wasm-gc)
  main/
    dsl_lexer.mbt        Lexer: Token ADT, character scanner
    dsl_parser.mbt       Parser: AST + recursive descent
    dsl_expr.mbt         Constraint expression AST + evaluator
    dsl_codegen.mbt      AST -> moonmodel.Model
    dsl_printer.mbt      AST -> DSL source (inverse of the parser)
    dsl_semantic.mbt     Reference resolution, self-reference, cycle detection
    solver.mbt           Constraint analysis engine
    solver_propagate.mbt Fixed-point interval propagation
    migration.mbt        Diff + SQL migration engine
    equiv.mbt            Semantic equivalence engine
    roundtrip.mbt        Round-trip verification
    property.mbt         xorshift64* PRNG + random model generator
    projector.mbt        Projector trait + DropReason ADT
    codegen.mbt          TypeScript / Zod / Prisma projections
    import.mbt           JSON Schema -> Model (reverse import)
    project.mbt          Projection pipeline
    presets.mbt          Preset models
    abi.mbt              JSON <-> moonmodel.Model conversion
    api.mbt              WASM ABI exports (10)
    jsonparse/           Minimal JSON wrapper (name-collision workaround)
    *_test.mbt           Engine test suites (14 files, 237 tests)
web/                    React + TypeScript frontend (31 files)
  src/components/
    EnginePanel.tsx      Engine playground (6 interactive engine tabs)
    OutputPanels.tsx     Seven projection panels
    FieldList.tsx        Field editor with drag reorder
    FieldEditor.tsx      Per-field constraint editor
    ModelDiagram.tsx     Canvas model relation graph
    CoverageMatrix.tsx   Constraint coverage matrix
    DropReport.tsx       Typed drop-reason report
    DiffPanel.tsx        Version diff view
    Versions.tsx         Version snapshots
    CodeHighlight.tsx    Syntax highlighting + change flash
    Onboarding.tsx       First-run guide
  src/lib/
    wasm.ts              Kernel loader + typed engine wrappers
    security.ts          Input validation / sanitization
    persistence.ts       localStorage persistence
    backup.ts            Workspace backup / restore
    history.ts           Undo / redo manager
    diff.ts              Model diff
    types.ts             ABI type definitions
    *.test.ts            Test suites (7 files, 94 tests)
backend/                Cloudflare Workers + D1 API (optional)
cli/                    Command-line tool (gen/check/migrate/verify/init)
vscode-extension/       VS Code plugin (DSL highlighting + preview)
models/                 Example models verified by the GitHub Action
```

---

## Quick Start

The kernel depends on the published `moonmodel` package, which is released against a newer spelling of the 32-bit integer than this kernel's toolchain uses. One setup step adjusts that dependency — it fetches it if needed, so it works on a fresh clone.

```powershell
# one-time setup: fetch and adjust the moonmodel dependency
pwsh -File scripts/patch_moonmodel.ps1
```

Windows users can run the whole thing at once — setup, build and test:

```powershell
.\setup.ps1
```

Manual, after the one-time setup above:

```bash
cd moonbit && moon build --target wasm-gc --release && moon test
cd ../web && npm install && npm run build && npm run test
npm run dev  # http://127.0.0.1:3000
```

---

## Architecture

```
                        ┌─────────────────────┐
                        │   Source (.dsl)     │
                        └──────────┬──────────┘
                                   │
              ┌────────────────────▼────────────────────┐
              │         MoonBit Kernel (wasm-gc)        │
              │                                         │
              │  ┌───────────┐   ┌──────────────────┐   │
              │  │  Lexer    │──▶│  Parser         │   │
              │  │  comments │   │  expressions    │   │
              │  │  operators│   │  precedence     │   │
              │  └───────────┘   └────────┬─────────┘   │
              │                            │             │
              │                    ┌───────▼────────┐    │
              │                    │ Semantic Check │    │
              │                    │ refs & cycles  │    │
              │                    └───────┬────────┘    │
              │                            │             │
              │              ┌─────────────▼──────────┐  │
              │              │      AST + Model       │  │
              │              └─────┬───────────┬──────┘  │
              │                    │           │         │
              │         ┌──────────▼───┐  ┌────▼─────┐  │
              │         │  Constraint  │  │ Migration│  │
              │         │   Solver     │  │  Engine  │  │
              │         │ + propagation│  │ + diff   │  │
              │         └──────────────┘  └──────────┘  │
              │                                         │
              │         ┌──────────┐  ┌──────────┐     │
              │         │Equivalence│  │Round-trip│     │
              │         └──────────┘  └──────────┘     │
              └────────────────────┬────────────────────┘
                                   │ moonmodel.Model
                                   ▼
        ┌──────────────────────────────────────────────────┐
        │  Projection (moonmodel): JSON Schema · OpenAPI   │
        │  SQL DDL · GraphQL · TypeScript · Zod · Prisma  │
        │  + typed drop report for every lost constraint  │
        └──────────────────────────────────────────────────┘
```

### The engine sources

| Engine | Source | Algorithm |
|--------|--------|-----------|
| DSL Compiler | `dsl_lexer.mbt`, `dsl_parser.mbt`, `dsl_expr.mbt` | Character scanner → recursive descent (primary → term → expr) |
| Cross-field resolution | `dsl_resolve.mbt` | Symbolic bounds, fixed-point resolution, unknown-reference and cycle detection |
| AST printer | `dsl_printer.mbt` | AST → DSL source (inverse of the parser) |
| Semantic check | `dsl_semantic.mbt` | Reference resolution, self-reference, cycle detection, constraint-system validation |
| Constraint solver | `solver.mbt`, `solver_propagate.mbt` | Interval arithmetic, dependency graph, fixed-point propagation over cross-field bounds |
| Migration engine | `migration.mbt` | Structured semantic diff, SQL generation, breaking-change classification |
| Equivalence | `equiv.mbt` | Type widening chain, constraint containment, collection recursion |
| Round-trip | `roundtrip.mbt` | Source → AST → source → AST, comparing every field, type and constraint |
| Property tests | `property.mbt` | xorshift64\* PRNG, random model generator, 7 invariants |

---

## Testing

| Suite | Count | Command |
|-------|-------|---------|
| MoonBit kernel | 237 | `cd moonbit && moon test` |
| &nbsp;&nbsp;— property-based | 16 | (12 invariants over 100+ random models, 4 PRNG properties) |
| &nbsp;&nbsp;— performance benchmarks | 7 | (100–200 field models, `monotonic_clock` budgets) |
| Frontend unit | 69 | `cd web && npm run test` |
| Frontend WASM integration | 25 | (same command; loads the real compiled kernel) |

### Test strategy

Beyond hand-picked examples, the kernel is verified with **property-based testing**: a deterministic xorshift64* PRNG (implemented in MoonBit) generates random models and constraint combinations, and invariants are checked across them.

| Property | Invariant |
|----------|-----------|
| Round-trip | `model -> DSL -> parse -> model` preserves every field, flag, and constraint |
| DSL totality | Generated DSL always parses with zero errors |
| Solver soundness | `least > most` is always detected; random models never crash the solver |
| Diff symmetry | `diff(a,b)` and `diff(b,a)` yield the same change count |
| Non-breaking add | Adding a field never produces a breaking change |
| Self-equivalence | A model is always equivalent to itself |
| Subtyping | Relaxing every field yields a subtype, never a supertype |

Performance budgets are asserted with `monotonic_clock` for models of 100-200 fields across projection, solving, parsing, diffing, round-trip, and equivalence.

**How CI verifies the kernel.** The `Kernel tests` workflow installs the MoonBit toolchain, fetches the `moonmodel` dependency, and runs `moon check` and `moon test` on the kernel source — all 237 tests, on every push and pull request that touches `moonbit/`. The toolchain cannot be pinned (the distribution host publishes only the `latest` and `nightly` archives), so the job installs `latest`; the kernel compiles and passes against both that release and the older one it was developed against.

The compiled kernel is verified separately: the artifact (`web/public/projdesk.wasm`) is committed to the repository and exercised by 25 real-WASM integration tests, and the `ProjDesk Generate` action runs the kernel over every model in `models/`, failing the build on a constraint conflict or a reference cycle.

---

## Known Limitations

- The DSL has no module or import mechanism — each model file is self-contained.
- Cross-field constraint reasoning runs on DSL sources. A model JSON carries only the resolved values, so `solve_constraints` on a model reasons per field; the cross-field resolution and cycle detection live in the DSL path.
- Migration SQL covers common `ALTER TABLE` cases; exotic dialects need manual review.
- The TypeScript and Prisma emitters carry no runtime constraint, so every constraint on their fields is reported as dropped; use the Zod target for runtime validation.
- The DSL grammar has no documentation construct, so a model's doc comments are not part of what the round-trip verifies.

## License

MIT
