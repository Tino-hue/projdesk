# ProjDesk — Model Engineering Workbench

**Live Demo**: https://tino-hue.github.io/projdesk/

A pure-browser workbench for the full lifecycle of a data model: **define → analyze → evolve → compare → verify**, with projection to JSON Schema / OpenAPI / SQL / GraphQL / TypeScript / Zod / Prisma as one of its outputs.

**Core value**: Five independent MoonBit algorithm engines that manage a model's lifecycle. Projection is delegated to [moonbitstack/moonmodel](https://mooncakes.io/packages/moonbitstack/moonmodel) — just one step in the pipeline, not the product.

---

## Core Job

> "Manage a data model like you manage code: define it in a language, analyze its constraints, evolve it safely with migrations, compare versions for equivalence, and verify it round-trips — then project it wherever you need it."

---

## Five Independent MoonBit Engines

| # | Engine | Source | What it does |
|---|--------|--------|--------------|
| 1 | **DSL Compiler** | `dsl_lexer.mbt` `dsl_parser.mbt` `dsl_codegen.mbt` | Hand-written lexer + recursive descent parser + AST codegen for a modeling language |
| 2 | **Constraint Solver** | `solver.mbt` | Detects conflicts, redundancies, and unsatisfiable constraints |
| 3 | **Migration Engine** | `migration.mbt` | Structured model diff + SQL `ALTER TABLE` + breaking-change detection |
| 4 | **Equivalence Checker** | `equiv.mbt` | Type subtyping + constraint containment + equivalence classification |
| 5 | **Round-trip Verifier** | `roundtrip.mbt` | Formal generate-parse-compare correctness verification |

78 dedicated MoonBit tests (93 total) prove each engine independently.

## Projection (delegated to moonmodel)

After lifecycle management, the model projects to seven targets via `moonbitstack/moonmodel`:

JSON Schema 2020-12 · OpenAPI 3.0/3.1/2.0 · SQL DDL (Postgres/SQLite/MySQL) · GraphQL SDL · TypeScript · Zod · Prisma

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

## Known Limitations

- The DSL is intentionally small (core modeling constructs only)
- The solver analyzes per-field constraints (no cross-field propagation yet)
- Migration SQL covers common ALTER TABLE cases; exotic dialects need manual review
- Multi-model Ref graph editing / URL sharing not yet in the frontend

## License

MIT
