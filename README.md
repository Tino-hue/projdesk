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

**93 MoonBit tests** (78 dedicated to the engines) + **80 frontend tests** (15 load the real WASM kernel end-to-end).

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
| `@optional` | Field not required |
| `@nullable` | Field may be null |
| `@unique` | Record-level unique constraint |
| `@distinct` | List items must differ |
| `[constraint=value]` | `least` `most` `over` `under` `step` `shortest` `longest` `pattern` `format` `options=[a,b]` |

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
                    Model Engineering Workbench
 ┌──────────────────────────────────────────────────────┐
 │   DSL Compiler ──> Constraint Solver ──> Migration    │
 │        │               │                   │          │
 │    define           analyze             evolve        │
 │        │               │                   │          │
 │   Equivalence <────── Round-trip <─────────┘          │
 │    compare           verify                            │
 └──────────┬───────────────────────────────────────────┘
            │ moonmodel.Model
            ▼
   Projection (moonmodel): 7 targets
```

---

## Testing

| Suite | Count | Command |
|-------|-------|---------|
| MoonBit kernel | 93 | `cd moonbit && moon test` |
| Frontend unit | 65 | `cd web && npm run test` |
| Frontend WASM integration | 15 | (same, loads real kernel) |

CI runs `moon check`, `moon fmt --check`, `moon info`, `moon test`, `vitest`, and `vite build` on every push.

---

## Known Limitations

- The DSL covers core modeling constructs only (no expressions or imports)
- The solver analyzes per-field constraints (no cross-field interval propagation yet)
- Migration SQL covers common ALTER TABLE cases; exotic dialects need manual review
- Round-trip verification is exposed via ABI but not yet surfaced as a UI action

## License

MIT
