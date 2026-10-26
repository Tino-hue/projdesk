# ProjDesk 3-Minute Demo Script

## Opening (20s)

> "ProjDesk is a model engineering workbench. Five MoonBit engines manage a data model's full lifecycle: define, analyze, evolve, compare, verify — and project it anywhere."

---

## Climax 1: DSL Compiler (40s)

1. Switch to **DSL mode**
2. Type: `model User { id: Big @unique, name: Text [longest=64] }`
3. Click **Parse** → the model appears instantly

> "A hand-written lexer and recursive descent parser in MoonBit turns a modeling language into a model. This is a compiler frontend."

---

## Climax 2: Constraint Solver (30s)

1. Edit a field: set `least = 10` and `most = 5`
2. The **constraint diagnosis panel** lights up red: "empty range"

> "The solver catches unsatisfiable constraints before they reach production — conflict, redundancy, and containment analysis."

---

## Climax 3: Migration Engine (40s)

1. Add a field, remove another, change a type
2. Open **Migration panel** → auto-generated `ALTER TABLE` SQL
3. Breaking changes are flagged

> "Evolve a model safely. Structured diff + SQL migration + breaking-change detection."

---

## Climax 4: Equivalence Checker (30s)

1. Compare two model versions
2. Result: `SubtypeOf` / `SupertypeOf` / `Incompatible`

> "Type subtyping and constraint containment — the model knows if two versions are compatible."

---

## Climax 5: Projection (20s)

> "And after the lifecycle, project to seven targets — JSON Schema, OpenAPI, SQL, GraphQL, TypeScript, Zod, Prisma — delegated to moonmodel, one step of the pipeline."

---

## Close (20s)

> "Five independent MoonBit engines, 93 tests, pure browser. That's ProjDesk."

**Run `moon test` live to show 93 green tests.**
