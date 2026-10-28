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
| 1 | **DSL Compiler** | `dsl_lexer.mbt` `dsl_parser.mbt` `dsl_codegen.mbt` | ~640 | Hand-written lexer + recursive descent parser + AST codegen |
| 2 | **Constraint Solver** | `solver.mbt` | ~220 | Conflict / redundancy / unsatisfiability analysis |
| 3 | **Migration Engine** | `migration.mbt` | ~310 | Structured model diff + SQL `ALTER TABLE` + breaking-change detection |
| 4 | **Equivalence Checker** | `equiv.mbt` | ~200 | Type subtyping + constraint containment + classification |
| 5 | **Round-trip Verifier** | `roundtrip.mbt` | ~175 | Formal generate-parse-compare correctness verification |

**150 MoonBit tests** (including 16 property-based tests over 100+ random models and 7 performance benchmarks) + **80 frontend tests** (15 load the real WASM kernel end-to-end).

---

## The Modeling Language

```model
model User {
  id: Big @unique                    // record-level uniqueness
  name: Text [shortest=1, longest=64] // length bounds
  email: Text [format=email]          // named format
  age: Int @optional [least=0, under=150]
  tags: List(Text) @optional @distinct
  home: Ref(Address)                  // reference to another model
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
| `// comment` | Line comment (ignored by the parser) |

Parse errors carry a line and column, and the parser recovers to continue with the next model.

---

## Engine Usage

All five engines are exposed through the WASM ABI and are runnable in the browser via the **Engine Playground** panel:

| ABI export | Input | Output |
|------------|-------|--------|
| `dsl_project(dsl)` | DSL source | Seven projections as JSON |
| `solve_constraints(model_json)` | Model JSON | Diagnosis list (conflict / redundant / warning) |
| `generate_migration(old_json, new_json)` | Two model JSONs | Change list + SQL migration + breaking count |
| `check_equivalence(a_json, b_json)` | Two model JSONs | Equivalent / SubtypeOf / SupertypeOf / Incompatible |
| `project_from_json(model_json)` | Model JSON | Seven projections + drop reasons |

---

## Relationship with moonmodel

| Capability | Implemented by |
|------------|----------------|
| Model data structures (Model/Field/Check) | moonmodel (like a compiler's AST definition) |
| Seven projection format conversions | moonmodel (like a compiler's backend) |
| **DSL lexer + parser + AST codegen** | **this project** |
| **Constraint conflict / redundancy reasoning** | **this project** |
| **Structured model diff + migration generation** | **this project** |
| **Type subtyping + equivalence classification** | **this project** |
| **Round-trip formal verification** | **this project** |

The five engines cover what a projection library cannot: they reason *about* the model rather than merely reformat it. Together they form a complete workflow — write DSL, solve constraints, evolve with migrations, compare versions, verify correctness, then project.

## Projection (delegated to moonmodel)

After lifecycle management, the model projects to seven targets:

JSON Schema 2020-12 · OpenAPI 3.0/3.1/2.0 · SQL DDL (Postgres/SQLite/MySQL) · GraphQL SDL · TypeScript · Zod · Prisma

Honest projection is preserved: every constraint a target cannot carry is reported as **dropped + reason** rather than silently discarded.

---

## Repository Layout

```
moonbit/                 MoonBit kernel (wasm-gc)
  main/
    dsl_lexer.mbt        Lexer: Token ADT, character scanner
    dsl_parser.mbt       Parser: AST + recursive descent
    dsl_codegen.mbt      AST -> moonmodel.Model
    solver.mbt           Constraint analysis engine
    migration.mbt        Diff + SQL migration engine
    equiv.mbt            Semantic equivalence engine
    roundtrip.mbt        Round-trip verification
    projector.mbt        Projector trait + DropReason ADT
    api.mbt              WASM ABI exports
    *_test.mbt           Engine test suites
web/                    React + TypeScript frontend
  src/components/
    EnginePanel.tsx      Engine playground (4 interactive engines)
    OutputPanels.tsx     Seven projection panels
    FieldList.tsx        Field editor with drag reorder
  src/lib/
    wasm.ts              Kernel loader + typed engine wrappers
    wasm.integration.test.ts  Real-WASM integration tests
backend/                Cloudflare Workers + D1 API (optional)
cli/                    Command-line generator
vscode-extension/       VS Code plugin
```

---

## Quick Start

```powershell
# Windows one-shot setup (applies moonmodel compat patch + builds + tests)
.\setup.ps1
# or
.\build.ps1
```

Manual:
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
| AST printer | `dsl_printer.mbt` | AST → DSL source (inverse of the parser) |
| Semantic check | `dsl_semantic.mbt` | Reference resolution, self-reference, cycle detection |
| Constraint solver | `solver.mbt`, `solver_propagate.mbt` | Interval arithmetic, dependency graph, fixed-point propagation |
| Migration engine | `migration.mbt` | Structured semantic diff, SQL generation, breaking-change classification |
| Equivalence | `equiv.mbt` | Type widening chain, constraint containment, collection recursion |
| Round-trip | `roundtrip.mbt` | Model → DSL → parse → field-by-field comparison |
| Property tests | `property.mbt` | xorshift64\* PRNG, random model generator, 7 invariants |

---

## Testing

| Suite | Count | Command |
|-------|-------|---------|
| MoonBit kernel | 150 | `cd moonbit && moon test` |
| Frontend unit | 65 | `cd web && npm run test` |
| Frontend WASM integration | 15 | (same, loads real kernel) |

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

CI runs `moon check`, `moon fmt --check`, `moon info`, `moon test`, `vitest`, and `vite build` on every push.

---

## Known Limitations

- The DSL covers core modeling constructs only (no expressions or imports)
- The solver analyzes per-field constraints (no cross-field interval propagation yet)
- Migration SQL covers common ALTER TABLE cases; exotic dialects need manual review
- Round-trip verification is exposed via ABI but not yet surfaced as a UI action

## License

MIT
