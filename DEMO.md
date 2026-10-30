# ProjDesk 3-Minute Demo Script

> **Framing (say this first):** "ProjDesk is a model engineering workbench. Five independent MoonBit algorithm engines manage a model's full lifecycle — define, analyze, evolve, compare, verify. Projection is the last step, not the product."

---

## Climax 1: DSL Compiler (50s)

1. Open the **Engine Playground** panel (top of the output area)
2. Tab: **DSL Compiler**
3. Type:
```
// the user account
model User {
  id: Big @unique
  name: Text [shortest=1, longest=64]
  addr: Nest {
    city: Text
  }
}
```
4. Click **Parse DSL** -> projections appear instantly

> "A hand-written lexer and recursive descent parser in MoonBit. Comments, nested models, and line-accurate parse errors."

**If asked "is this just a parser demo":** "The parser turns source into a `moonmodel.Model`, which then feeds the other four engines."

---

## Climax 2: Constraint Solver (35s)

1. Tab: **Constraint Solver** -> **Analyze Constraints**
2. Then edit a field: set `least = 10` and `most = 5`
3. Re-run -> red conflict: `[CONFLICT] x: least(10) > most(5): empty range`

> "Not a fixed message table. Interval analysis, implication and redundancy detection, containment relations, option-set cross-validation — a real constraint reasoner."

---

## Climax 3: Migration Engine (40s)

1. Tab: **Migration** -> **Generate Migration**
2. Shows structured diff + generated `ALTER TABLE` SQL + breaking-change flags

> "Structured semantic diff, not text diff. It knows a field removal breaks and a type narrowing breaks, and it emits dialect-specific SQL."

---

## Climax 4: Equivalence Checker (30s)

1. Tab: **Equivalence** -> **Check Equivalence**
2. Result: `SubtypeOf` / `SupertypeOf` / `Incompatible`

> "Type subtyping chain, constraint containment, nested model and collection recursion. The tool knows whether two model versions are compatible."

---

## Climax 5: Round-trip Verification (25s)

1. Tab: **Round-trip** -> **Verify Round-trip**
2. Result: verified / failed with reason

> "Formal generate-parse-compare. The model round-trips without losing a field or a constraint."

---

## Closing (20s)

> "Five independent MoonBit engines, 3691 lines of engine code, 251 tests including property-based verification over 100 random models. That's ProjDesk."

**Run `moon test` live to show 251 green tests.**

---

## Backup Q&A

**"Isn't the projection just moonmodel?"**
> "Projection is one step of seven outputs. The five engines are what moonmodel doesn't cover — a compiler frontend, a constraint reasoner, a migration engine, a type-equivalence checker, and a formal verifier. That's 3691 lines of independent MoonBit code."

**"Why MoonBit for this?"**
> "The kernel compiles to wasm-gc and runs entirely in the browser — one binary, no server. The pattern matching and ADT support made the compiler frontend and type-equivalence engine direct rather than ceremony."

**"What did you build that Prisma/Drizzle don't?"**
> "They generate code from a model. This one reasons about the model: whether its constraints are satisfiable, whether two versions are compatible, what SQL migration a change implies, and whether it survives a round-trip."

**"How do you know it works?"**
> "251 MoonBit tests, 16 of them property-based — a deterministic PRNG generates random models and asserts 12 invariants like round-trip preservation and diff symmetry. Plus 26 frontend tests that load the real WASM binary and 4 that render the workbench to check all seven panels."
