# ProjDesk — Model Engineering Workbench

**Live Demo**: https://tino-hue.github.io/projdesk/

A pure-browser toolchain for the **correctness of a data model**: is the model itself consistent, are two versions compatible, does projecting it to JSON Schema / OpenAPI / SQL / GraphQL / TypeScript / Zod / Prisma lose anything, and does the definition survive the round-trip.

**Core value**: Five independent MoonBit algorithm engines. The MoonBit ecosystem already has schema libraries ([moon_zod](https://mooncakes.io/packages/Betterlol/moon_zod), [moonschema](https://mooncakes.io/packages/QuietlyChan/moonschema), [moonmodel](https://mooncakes.io/packages/moonbitstack/moonmodel)) that turn a model into artifacts, and schema-diff tools ([moon_schema_plan](https://mooncakes.io/packages/kath61105/moon_schema_plan), [moon-data-contract](https://mooncakes.io/packages/lyjttio/moon-data-contract)) that compare two models. ProjDesk answers the question those tools leave open: **is the model right, and is the artifact faithful?** The ecosystem generates; this verifies.

---

## Core Job

> "Manage a data model like you manage code: define it in a language, analyze its constraints, evolve it safely with migrations, compare versions for equivalence, and verify it round-trips — then project it wherever you need it."

---

## Why this, and not a schema library

The MoonBit ecosystem is not empty. It already contains schema libraries that define and validate models, diff tools that compare two models and plan migrations, and code generators that emit JSON Schema or Zod. So the interesting question is not "is this new?" but **"which question does this answer that they do not?"**

Three, and each one is checkable from this repository.

### 1. Is the model itself consistent — before any data exists?

Schema validators judge a *value*: `moon_zod`'s `parse`/`safe_parse` and `moonschema`'s validator both take an instance and report whether it satisfies the schema. The constraint solver here judges the *constraint system*: given only a model, it decides whether the system has a solution at all — interval algebra, fixed-point propagation across fields, implication and redundancy analysis, containment relations.

The sharpest case is a conflict that **no per-field check can see**, because one field's constraint is fine on its own and the contradiction only appears once a reference between fields is resolved:

```bash
node cli/index.js contrast examples/CrossFieldConflict.dsl
```

```
Model: Pair

  low (Int)
    projection (moonmodel)  format: int32  minimum: 10
    solver (this project)   no findings
  high (Int)
    projection (moonmodel)  format: int32  maximum: 5  exclusiveMinimum: 10
    solver (this project)   [CONFLICT] high: over(10) >= most(5): impossible

The projection carries these through without saying anything about them.
```

`low`'s own bound is perfectly satisfiable. `high` borrows `low`'s lower bound, and *that* is what makes `over(10)` and `most(5)` contradict each other. The projection writes the impossible range out — `exclusiveMinimum: 10` together with `maximum: 5` — and says nothing about it. A validator cannot report this: it would have to judge a value that satisfies `low` against `high`, and it has no way to ask whether the constraint system as a whole has a solution.

Two more kinds of the same question, on `examples/Conflicting.dsl`: `least=0` together with `most=-1` is an empty range, and `Text [longest=3, options=[toolong]]` is a closed set that does not fit its length bound.

```bash
node cli/index.js check examples/Conflicting.dsl
```

None of these depend on a value existing, so none of them are validation questions.

### 2. Does the projection lose anything — and is that visible?

Every projector silently drops what its target cannot express. Here it is reported: per target, per field, per constraint, with the reason (9 typed drop reasons).

```bash
node cli/index.js gen models/Order.dsl && cat projdesk-out/drops.txt
```

And it is not only our own output that gets measured. `moonmodel` — the library this project builds on — writes `minimum: 0` next to `maximum: -1` and emits a schema no value can satisfy, without saying so:

```bash
node cli/index.js contrast examples/Conflicting.dsl
```

### 3. Does the definition survive the toolchain?

Parse, print, parse again, compare every field, every type and every constraint — nested models and all twelve constraint kinds included. The schema libraries in the ecosystem do not own a printer, so they cannot ask this question at all.

### And the custom notation has exactly one reason to exist

A field's constraint may reference another field's constraint: `b: Int [over=a.least]` means "b's lower bound comes from a's lower bound". In the data model behind JSON Schema, Zod and `moon_zod`, a constraint is a constant attached to a single field — there is nowhere to put *a constraint that depends on another constraint*. Judging satisfiability across fields needs a notation that can express it, so that is the one thing the notation is for. Everything else is reused from the ecosystem: the model data structures and four of the projection backends come from `moonmodel`, and runtime validation belongs to libraries like `moon_zod`.

### Where the overlap actually is

Stated plainly, because parts of this do overlap:

| Ecosystem | What it does | Relationship |
|---|---|---|
| [moon_zod](https://mooncakes.io/packages/Betterlol/moon_zod), [moonschema](https://mooncakes.io/packages/QuietlyChan/moonschema), [moonbitstack/moonschema](https://mooncakes.io/packages/moonbitstack/moonschema), [colmugx/json-schema](https://mooncakes.io/packages/colmugx/json-schema) | Schema definition and **instance-level** runtime validation; export to JSON Schema | Complementary: they judge whether a *value* is valid; this judges whether the *model* is consistent — statically, with no data |
| [moon_schema_plan](https://mooncakes.io/packages/kath61105/moon_schema_plan), [moon-data-contract](https://mooncakes.io/packages/lyjttio/moon-data-contract), [moonpack](https://mooncakes.io/packages/001-Elsa/moonpack), [moon_proto](https://mooncakes.io/packages/123123213weqw/moon_proto) | Schema diff, migration planning, destructive-change gates, old/new compatibility checks | Complementary: we provide the semantic diff and compatibility *engines*, plus the two things these do not cover — projection fidelity and definition round-trip |
| [mizchi/codegen](https://mooncakes.io/packages/mizchi/codegen), [moonmodel](https://mooncakes.io/packages/moonbitstack/moonmodel) | Generic IR and multi-target emitters | **Overlapping on three emitters** — see below |
| [Orion](https://mooncakes.io/packages/wflixu/Orion) | Schema DSL, CRUD, migration SQL | The migration engine here reasons over *model semantics* (constraints, references, value sets), not table structure |

The honest part: of the seven projection targets, JSON Schema / OpenAPI / SQL / GraphQL come from `moonmodel`. The TypeScript / Zod / Prisma emitters are ours, and that **does** overlap with a generic code generator. They are ours because they must understand model semantics — constraints, references, value sets — which a generic IR does not express. But all three sit behind the same `Projector` trait, so an ecosystem emitter that understands model semantics could replace them. The overlap is three emitters; the five engines are not in it.

---

## Verify the claims

Everything this project claims can be checked from this repository alone. Each row names the code that implements the claim and the command that shows it.

| Claim | Implemented in | Check it with |
|---|---|---|
| Five independent MoonBit engines | `moonbit/main/` — the table below lists every file and its size | `wc -l moonbit/main/roundtrip.mbt` |
| 251 kernel tests | `moonbit/main/*_test.mbt` | `cd moonbit && moon test` |
| The kernel compiles with zero warnings | the same source | `cd moonbit && moon check` |
| 95 frontend tests, 26 of them against the real compiled kernel | `web/src/lib/*.test.ts` | `cd web && npm run test` |
| 11 exports on the compiled kernel | `moonbit/main/api.mbt` | the command below |
| Seven projections, each with a typed drop report | `moonbit/main/codegen.mbt` `moonbit/main/projector.mbt` | `node cli/index.js gen models/Order.dsl && cat projdesk-out/drops.txt` |
| Cross-field constraints resolve; reference cycles are reported | `moonbit/main/dsl_resolve.mbt` | `node cli/index.js verify models/CrossField.dsl` |
| The solver finds conflicts the projection carries in silence | `moonbit/main/independence_test.mbt` | `node cli/index.js contrast examples/Conflicting.dsl` |
| The round-trip verifier compares every field, type and constraint | `moonbit/main/roundtrip.mbt` | `node cli/index.js verify models/Order.dsl` |
| The model is judged consistent before any data exists | `moonbit/main/solver.mbt` `moonbit/main/solver_propagate.mbt` | `node cli/index.js contrast examples/CrossFieldConflict.dsl` |
| What each projection target silently drops is reported per constraint | `moonbit/main/projector.mbt` | `node cli/index.js gen models/Order.dsl && cat projdesk-out/drops.txt` |
| The boundary against the existing ecosystem is stated, not implied | this file | the "Why this, and not a schema library" section |
| A failed round-trip says what failed and where, as data | `moonbit/main/roundtrip.mbt` (`RoundTripError`) | `node cli/index.js verify examples/Unprintable.dsl --json` |
| The kernel's own tests run on every push | `.github/workflows/kernel.yml` | the "Kernel tests" check on any commit |
| The published kernel is consumable by a module that has nothing to do with this repository | `scripts/verify-registry-consumption.js` | `node scripts/verify-registry-consumption.js` |
| The projection formats come from moonmodel, not from here | `NOTICE.md` | — |

```bash
# the eleven exports of the compiled kernel
node -e "const fs=require('fs');WebAssembly.instantiate(fs.readFileSync('web/public/projdesk.wasm'),{},{builtins:['js-string'],importedStringConstants:'_'}).then(r=>console.log(Object.keys(r.instance.exports).sort().join('\n')))"
```

Three commands, about two minutes:

```bash
cd moonbit && moon check && moon test   # the kernel: zero warnings, 251 tests
cd ../web && npm run test               # the frontend: 95 tests
cd .. && node cli/index.js verify models/CrossField.dsl
```

---

## Five Independent MoonBit Engines

| # | Engine | Source | Lines | What it does |
|---|--------|--------|-------|--------------|
| 1 | **DSL Compiler** | `dsl_lexer.mbt` `dsl_parser.mbt` `dsl_expr.mbt` `dsl_codegen.mbt` `dsl_printer.mbt` `dsl_semantic.mbt` `dsl_resolve.mbt` | 2127 | Hand-written lexer + recursive descent parser + constraint-expression evaluator + AST codegen + inverse AST printer + semantic checks + cross-field bound resolution |
| 2 | **Constraint Solver** | `solver.mbt` `solver_propagate.mbt` | 579 | Conflict / redundancy / containment analysis, cross-field bound resolution, fixed-point interval propagation, reference-cycle detection |
| 3 | **Migration Engine** | `migration.mbt` | 364 | Structured model diff + SQL `ALTER TABLE` + breaking-change detection |
| 4 | **Equivalence Checker** | `equiv.mbt` | 229 | Type subtyping + constraint containment + classification |
| 5 | **Round-trip Verifier** | `roundtrip.mbt` | 433 | Source-level generate-parse-compare, comparing every field, type and constraint; failures are typed, not prose |
| | **Five engines** | | **3732** | |

On top of the engines the kernel carries **2008 lines** of supporting infrastructure and property-test machinery (`projector.mbt` `codegen.mbt` `import.mbt` `project.mbt` `presets.mbt` `abi.mbt` `api.mbt` `property.mbt`) — **5740 lines** of MoonBit implementation, plus **3225 lines** of test code.

**251 MoonBit tests** (16 property-based — 12 invariants asserted over 100+ random models, plus 4 PRNG properties — and 7 performance benchmarks) + **95 frontend tests** (26 load the real WASM kernel end-to-end, and 4 render the workbench to assert that all seven projection panels appear).

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

All five engines — plus the semantic checker — are exposed through the WASM ABI (**11 exports**) and are runnable in the browser via the **Engine Playground** panel (6 tabs: DSL Compiler, Constraint Solver, Migration, Equivalence, Round-trip, Semantic Check):

| ABI export | Input | Output |
|------------|-------|--------|
| `dsl_project(dsl)` | DSL source | Seven projections as JSON |
| `solve_constraints(model_json)` | Model JSON | Diagnosis list (conflict / redundant / warning) |
| `generate_migration(old_json, new_json)` | Two model JSONs | Change list + SQL migration + breaking count |
| `check_equivalence(a_json, b_json)` | Two model JSONs | Equivalent / SubtypeOf / SupertypeOf / Incompatible |
| `verify_roundtrip(model_json)` | Model JSON | Pass / Fail + message + failure kind and stage |
| `verify_roundtrip_dsl(dsl)` | DSL source | Pass / Fail + message + failure kind and stage |
| `dsl_to_model(dsl)` | DSL source | The model as JSON, for the other commands |
| `check_semantics(dsl)` | DSL source | Unresolved references, self-references, cycles |
| `project_from_json(model_json)` | Model JSON | Seven projections + drop reasons |
| `import_from_json_schema_str(schema)` | JSON Schema text | Model JSON (reverse import) |
| `get_presets_json()` | — | Preset models |

---

## What is ours, and what the ecosystem already provides

| Capability | Implemented by |
|------------|----------------|
| Model data structures (Model/Field/Check) | moonmodel (like a compiler's AST definition) |
| Seven projection format conversions | moonmodel (like a compiler's backend) |
| **DSL lexer + parser + AST codegen** | **this project** |
| **Constraint conflict / redundancy / cross-field reasoning** | **this project** |
| **Structured model diff + migration generation** | **this project** |
| **Type subtyping + equivalence classification** | **this project** |
| **Round-trip formal verification** | **this project** |

The five engines cover what a projection library cannot: they reason *about* the model rather than merely reformat it. Together they form a complete workflow — write DSL, solve constraints, evolve with migrations, compare versions, verify correctness, then project. The wider ecosystem boundary — which existing libraries already cover which of these — is set out in [Why this, and not a schema library](#why-this-and-not-a-schema-library).

## What the engines do that projection does not

Projection formats a model. The engines reason about it. The difference is not a matter of taste — it is measurable, and this repository measures it.

`examples/Conflicting.dsl` is a model whose constraints cannot be satisfied. The two sides, side by side:

````
$ projdesk contrast examples/Conflicting.dsl

Model: Reading

  id (Big)
    projection (moonmodel)  format: int64
    solver (this project)   no findings
  floor (Int)
    projection (moonmodel)  format: int32  minimum: 0
    solver (this project)   no findings
  ceiling (Int)
    projection (moonmodel)  format: int32  minimum: 0  maximum: -1
    solver (this project)   [CONFLICT] ceiling: least(0) > most(-1): empty range
  code (Text)
    projection (moonmodel)  maxLength: 3  enum: toolong
    solver (this project)   [CONFLICT] code: option 'toolong' exceeds longest(3)

The projection carries these through without saying anything about them.
````

moonmodel writes `minimum: 0` next to `maximum: -1` and emits a schema no value can satisfy. It has no notion that the range is empty, that a closed set does not fit its length bound, or that one field's bound may be another field's bound.

That difference is asserted rather than asserted-about: `moonbit/main/independence_test.mbt` runs both sides over randomly generated models and checks that every conflict the solver reports is carried through the projection in silence.

### Failures are typed, not prose

A verifier that can only say "something is wrong" is a verifier nobody can act on. The round-trip engine returns a `RoundTripError` — a MoonBit error type with one variant per way a round-trip can fail — and names the source that broke:

````
$ projdesk verify examples/Unprintable.dsl --json
{
  "ok": false,
  "issues": [],
  "issue_count": 0,
  "roundtrip": "parse errors in printed DSL: line 2:22: expected =, got ]",
  "roundtrip_reason": "parse_error",
  "roundtrip_stage": "printed"
}
````

`parse_error` says what happened; `printed` says it happened to the source the printer produced rather than to the source that was handed in — the difference between a bad model and a bug in the printer. The type is a `suberror`, so it can be raised and caught, not only matched on.

---

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
    dsl_resolve.mbt     Cross-field bound resolution (fixed point)
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
    *_test.mbt           Engine test suites (15 files, 251 tests)
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
    *.test.ts            Test suites (7 files, 95 tests)
backend/                Cloudflare Workers + D1 API (optional)
cli/                    Command-line tool (gen/check/contrast/migrate/verify/init)
vscode-extension/       VS Code plugin (DSL highlighting + preview)
models/                 Example models verified by the GitHub Action
examples/               Worked examples, including one that contradicts itself
```

---

## Quick Start

The kernel needs **MoonBit 0.1.20261023 or newer** — the release that spells the 32-bit integer `Int32` the way the `moonmodel` package is published. An older toolchain compiles the dependency but not this kernel.

Windows users can run the whole thing at once — build and test:

```powershell
.\setup.ps1
```

Manual:

```bash
cd moonbit && moon build --target wasm-gc --release && moon test
cd ../web && npm install && npm run build && npm run test
npm run dev  # http://127.0.0.1:3000
```

## Using the kernel as a dependency

The kernel is published to Mooncakes as `Tino-hue/projdesk-kernel`:

```bash
moon add Tino-hue/projdesk-kernel
```

It exports the WASM ABI, so it is a foreign library — a consuming package imports it under an alias:

```
# cmd/demo/moon.pkg
import {
  "Tino-hue/projdesk-kernel/main" @projdesk,
}

pkgtype(kind: "executable")
```

```moonbit
// cmd/demo/main.mbt
fn main {
  // the kernel compiles a DSL source and projects it to all seven targets
  let (projections, problems) = @projdesk.dsl_project(
    "model User {\n  id: Big @unique\n  name: Text [shortest=1, longest=64]\n}",
  )
  println(projections)
  for problem in problems {
    println(problem)
  }
}
```

```bash
moon run cmd/demo
```

The alias is not optional in practice: the kernel's package is called `main`, and so is the package you would import it from.

To check that the *published* package — not this checkout — is consumable:

```bash
node scripts/verify-registry-consumption.js
```

It resolves the package from the registry, compiles a throwaway consumer module against it, runs it, and fails unless all seven projections come out.

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
| Cross-field resolution | `dsl_resolve.mbt` | Symbolic bounds, fixed-point resolution, unknown-reference detection |
| Constraint solver | `solver.mbt`, `solver_propagate.mbt` | Interval arithmetic, dependency graph, fixed-point propagation over cross-field bounds |
| Migration engine | `migration.mbt` | Structured semantic diff, SQL generation, breaking-change classification |
| Equivalence | `equiv.mbt` | Type widening chain, constraint containment, collection recursion |
| Round-trip | `roundtrip.mbt` | Source → AST → source → AST, comparing every field, type and constraint |
| Property tests | `property.mbt` | xorshift64\* PRNG, random model generator, 7 invariants |

---

## Testing

| Suite | Count | Command |
|-------|-------|---------|
| MoonBit kernel | 251 | `cd moonbit && moon test` |
| &nbsp;&nbsp;— property-based | 16 | (12 invariants over 100+ random models, 4 PRNG properties) |
| &nbsp;&nbsp;— performance benchmarks | 7 | (100–200 field models, `monotonic_clock` budgets) |
| Frontend unit | 69 | `cd web && npm run test` |
| Frontend WASM integration | 26 | (same command; loads the real compiled kernel) |

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

**How CI verifies the kernel.** The `Kernel tests` workflow installs the MoonBit toolchain, fetches the `moonmodel` dependency, and runs `moon check` and `moon test` on the kernel source — all 251 tests, on every push and pull request that touches `moonbit/`. The toolchain cannot be pinned (the distribution host publishes only the `latest` and `nightly` archives), so the job installs `latest`; the kernel compiles and passes against both that release and the older one it was developed against.

The compiled kernel is verified separately: the artifact (`web/public/projdesk.wasm`) is committed to the repository and exercised by 26 real-WASM integration tests, and the `ProjDesk Generate` action runs the kernel over every model in `models/`, failing the build on a constraint conflict or a reference cycle.

---

## Known Limitations

- The DSL has no module or import mechanism — each model file is self-contained.
- Cross-field constraint reasoning runs on DSL sources. A model JSON carries only the resolved values, so `solve_constraints` on a model reasons per field; the cross-field resolution and cycle detection live in the DSL path.
- Migration SQL covers common `ALTER TABLE` cases; exotic dialects need manual review.
- The TypeScript and Prisma emitters carry no runtime constraint, so every constraint on their fields is reported as dropped; use the Zod target for runtime validation.
- The DSL grammar has no documentation construct, so a model's doc comments are not part of what the round-trip verifies.

## License

MIT
