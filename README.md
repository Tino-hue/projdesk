# ProjDesk — One Definition, Four Projections

> **A pure-browser "model description → multi-target projection" workbench.**
> Declare a business object with a form, and the page simultaneously generates and live-refreshes: **JSON Schema / OpenAPI / SQL DDL / GraphQL SDL**.

**Difference from Depsight**: Depsight performs dependency analysis and supply-chain diagnostics. ProjDesk operates at the metadata/contract layer for multi-target projection generation. The two have zero functional overlap and this is not a continuation of the same work.

---

## Core Job

> "When I need to declare a business object, help me say it once clearly, and immediately see what it looks like in four worlds; change one constraint and all four artifacts update together; if a target cannot carry something, honestly tell me why."

### Three Product Principles

1. **One source of truth, four projections** — all projection algorithms live in the MoonBit kernel; the frontend must never implement schema/sql/sdl generation itself.
2. **Honest projection** — constraints a target cannot carry must be shown as "dropped + reason"; never silently beautify or discard.
3. **Demo first** — any edit must refresh all four panels smoothly; prefer cutting features over laggy interaction.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Web Frontend (React)               │
│   Form Editor ──→ ABI Serialize ──→ 4-Panel Display │
│                 (TypeScript)       + Drop Reports   │
└────────────────────────┬────────────────────────────┘
                         │ JSON string (js-string builtins)
                         ▼
┌─────────────────────────────────────────────────────┐
│              MoonBit Kernel (wasm-gc)               │
│                                                     │
│  parse_input ──→ moonmodel.Model ──→ project_all     │
│                                      │              │
│                    ┌─────────────────┼──────────┐   │
│                    ▼        ▼        ▼          ▼   │
│               JSON Schema  OpenAPI  SQL DDL  SDL    │
│               + drops      + drops  + drops  +drops │
│                                                     │
│  Dependency: moonbitstack/moonmodel                 │
└─────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- [MoonBit toolchain](https://www.moonbitlang.cn/)
- Node.js ≥ 18

### One-shot Build

```bash
make all
```

### Step by Step

```bash
# 1. Compile MoonBit kernel
cd moonbit
moon build --target wasm-gc --release
# Artifact: _build/wasm-gc/release/build/main/main.wasm

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
# Open http://127.0.0.1:3000
```

---

## Relationship with moonmodel

ProjDesk's projection capabilities are entirely provided by [moonbitstack/moonmodel](https://mooncakes.io/packages/moonbitstack/moonmodel):

| Subpackage | Function |
|------------|----------|
| `moonmodel` | Core types: Model / Field / Check / Type |
| `moonmodel/json` | JSON Schema 2020-12 projection |
| `moonmodel/open` | OpenAPI Schema Object projection (2.0/3.0/3.1) |
| `moonmodel/sql` | SQL DDL projection (SQLite/Postgres/MySQL) |
| `moonmodel/sdl` | GraphQL SDL projection |

ProjDesk adds on top:
- **Drop-reason analysis**: per-constraint checks whether each target can carry it, outputs structured `DropReason`
- **WASM ABI**: JSON string in/out browser calling interface
- **Preset models**: User / Order / Address

> **Compatibility note**: moonmodel 0.1.0 uses the deprecated `Int32` type (renamed to `Int` in current MoonBit). A minimal `Int32→Int` patch is applied to the `.mooncakes` cache source at build time, without changing business logic.

---

## MoonBit Depth Points

| Technical Point | Where Used |
|-----------------|------------|
| **ADT / enum** | `Type`'s 13 type variants (incl. recursive `List(Type)` / `Dict(Type)` / `Nest(Model)`) |
| **Pattern matching** | Bidirectional mapping in `parse_type` / `type_to_json` |
| **`pub(all)` structs** | `DropReason` / `ProjectionResult` cross-package use |
| **`raise` + `try/catch`** | JSON parse error handling |
| **wasm-gc + js-string** | String params zero-copy to JS |
| **`#export_name`** | Stable ABI exports |
| **Contract tests** | 21 `moon test` cases locking required×nullable×four-target semantics |

---

## Known Limitations

- OpenAPI version fixed at 3.0 (V1 can extend 2.0/3.1 switching)
- SQL dialect fixed at Postgres (V1 can extend SQLite/MySQL)
- GraphQL `options` does not auto-generate enum types
- Multi-model Ref graph / URL sharing not yet implemented

---

## Acceptance Checklist

### A. Features
- [x] Page loads preset samples within 10 seconds, all four panels show output immediately
- [x] Editing fields/constraints updates all four panels correctly and synchronously
- [x] `required` and `nullable` are independent, with correct semantics across all four targets
- [x] Drop reports honestly reflect constraints each target cannot carry, with reasons
- [x] Copy/export all four artifacts
- [x] Frontend contains zero schema/sql/sdl generation algorithms

### B. Quality
- [x] `moon test` all green (21 contract tests)
- [x] Web-side tests all green (5 ABI tests)
- [x] `npm run build` passes
- [x] `make all` completes the full pipeline

### C. Repository
- [x] README.md (positioning, architecture, steps, limitations)
- [x] DEMO.md (3-minute demo script)
- [x] LICENSE (MIT)
- [x] Makefile

### E. Compliance
- [x] Zero functional overlap with Depsight
- [x] No dependency on legacy FractMoon/Depsight business code

---

## License

MIT
