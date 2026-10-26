# ProjDesk - One Definition, Four Projections

**Live Demo**: https://tino-hue.github.io/projdesk/

A pure-browser "model description to multi-target projection" workbench. Declare a business object with a form, and the page simultaneously generates and live-refreshes: **JSON Schema / OpenAPI / SQL DDL / GraphQL SDL**.

**Difference from Depsight**: Depsight performs dependency analysis and supply-chain diagnostics. ProjDesk operates at the metadata/contract layer for multi-target projection generation. The two have zero functional overlap.

---

## Core Job

> "When I need to declare a business object, help me say it once clearly, and immediately see what it looks like in four worlds; change one constraint and all four artifacts update together; if a target cannot carry something, honestly tell me why."

### Three Product Principles

1. **One source of truth, four projections** - all projection algorithms live in the MoonBit kernel; the frontend never implements schema/sql/sdl generation.
2. **Honest projection** - constraints a target cannot carry must be shown as "dropped + reason"; never silently beautify or discard.
3. **Demo first** - any edit must refresh all four panels smoothly.

---

## Architecture

```
+------------------------------------------------------+
|                Web Frontend (React)                  |
|   Form Editor --> ABI Serialize --> 4-Panel Display  |
|                 (TypeScript)       + Drop Reports    |
+------------------------------------------------------+
                         |
                         | JSON string (js-string builtins)
                         v
+------------------------------------------------------+
|              MoonBit Kernel (wasm-gc)                |
|                                                      |
|  parse_input --> moonmodel.Model --> project_all     |
|                                       |              |
|                    +------------------+----------+   |
|                    v          v         v         v   |
|               JSON Schema  OpenAPI  SQL DDL     SDL  |
|               + drops      + drops  + drops   +drops |
|                                                      |
|  Dependency: moonbitstack/moonmodel                  |
+------------------------------------------------------+
```

---

## Quick Start

### Prerequisites

- [MoonBit toolchain](https://www.moonbitlang.cn/)
- Node.js 18+

### Fresh Clone Setup

`powershell
# Windows
.\setup.ps1

# Linux / macOS (manual)
cd moonbit && moon build --target wasm-gc && moon test
cp _build/wasm-gc/release/build/main/main.wasm ../web/public/projdesk.wasm
cd ../web && npm install && npm run build && npm run test
`

> setup.ps1 automatically applies a moonmodel compatibility patch (Int32 -> Int) needed for the current MoonBit toolchain.

### One-shot Build

```bash
# Linux / macOS
make all

# Windows PowerShell
.\build.ps1
```

### Step by Step

```bash
# 1. Compile MoonBit kernel
cd moonbit
moon build --target wasm-gc --release

# 2. Run kernel contract tests
moon test

# 3. Build frontend
cd ../web
npm install
npm run build

# 4. Run frontend tests
npm run test

# 5. Local preview (port 3000)
npm run dev
```

---

## Relationship with moonmodel

ProjDesk's projection capabilities are provided by [moonbitstack/moonmodel](https://mooncakes.io/packages/moonbitstack/moonmodel):

| Subpackage | Function |
|------------|----------|
| `moonmodel` | Core types: Model / Field / Check / Type |
| `moonmodel/json` | JSON Schema 2020-12 projection |
| `moonmodel/open` | OpenAPI Schema Object (2.0/3.0/3.1) |
| `moonmodel/sql` | SQL DDL (SQLite/Postgres/MySQL) |
| `moonmodel/sdl` | GraphQL SDL |

ProjDesk adds on top:
- **Drop-reason analysis**: per-constraint check with structured `DropReason`
- **WASM ABI**: JSON string in/out browser interface
- **Preset models**: User / Order / Address
- **Syntax highlighting + change diff + Canvas model diagram**
- **Dialect switching, model import/export, coverage matrix**

---

## MoonBit Depth Points

| Technical Point | Where Used |
|-----------------|------------|
| ADT / enum | `Type`'s 13 variants (recursive `List`/`Dict`/`Nest`) |
| Pattern matching | Bidirectional `parse_type` / `type_to_json` |
| `pub(all)` structs | `DropReason` / `ProjectionResult` cross-package |
| `raise` + `try/catch` | JSON parse error handling |
| wasm-gc + js-string | String zero-copy to JS |
| `#export_name` | Stable ABI exports |
| Contract tests | 41 `moon test` cases |

---

## Testing

| Layer | Count | Coverage |
|-------|-------|----------|
| Kernel (`moon test`) | 41 | Types, constraints, required/nullable, drops, dialects, presets, ABI |
| Frontend (`vitest`) | 16 | Serialization, Check fields, nested types, truth table, output shape |
| **Total** | **57** | All green |

---

## MoonBit Engineering Depth (Independent Core)

Beyond the moonmodel projection library, ProjDesk implements five independent MoonBit algorithm engines:

| Engine | Source | What it does |
|--------|--------|--------------|
| **DSL Compiler** | `dsl_lexer.mbt`, `dsl_parser.mbt`, `dsl_codegen.mbt` | Hand-written lexer + recursive descent parser + AST codegen for a modeling language: `model User { id: Big @unique }` |
| **Constraint Solver** | `solver.mbt` | Conflict/redundancy/satisfiability analysis over constraint combinations (empty ranges, subsumption, options-vs-length) |
| **Migration Engine** | `migration.mbt` | Structured model diff + SQL `ALTER TABLE` generation + breaking-change detection |
| **Semantic Equivalence** | `equiv.mbt` | Type subtyping chain (Int->Big->Real), constraint containment, mixed-direction detection |
| **Round-trip Framework** | `roundtrip.mbt` | Formal generate-parse-compare verification of projection correctness |

These are exposed through the WASM ABI (`dsl_project`, `solve_constraints`, `generate_migration`, `check_equivalence`) and covered by 78 dedicated tests.

## Known Limitations

- GraphQL `options` does not auto-generate enum types
- Multi-model Ref graph editing / URL sharing not yet implemented

---

## Privacy and Data

- All data is stored **locally** in your browser (localStorage). No data is sent to any server.
- URL sharing encodes your model into the URL hash. Be aware that URLs may be logged in browser history or server logs.
- Use **Backup** to export your models as a JSON file for safekeeping.
- Generated schema files may contain your field names and documentation. Review before sharing externally.

## License

MIT


