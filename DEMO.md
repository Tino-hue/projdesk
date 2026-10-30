# ProjDesk 3-Minute Demo Script

> **Framing (say this first):** "MoonBit already has schema libraries — moon_zod, moonschema — and schema-diff tools like moon_schema_plan. Those turn a model into artifacts and compare two models. ProjDesk answers the question they leave open: **is the model itself consistent, and did the projection lose anything?** The ecosystem generates; this verifies. Five independent MoonBit algorithm engines — constraint reasoning, round-trip verification, migration, equivalence, and a compiler front end."

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

> **The distinction that matters:** "moon_zod asks whether *this value* is valid. This asks whether *the model* has a solution at all — before any data exists. `least=0` with `most=-1` is a contradiction in the model, not in a payload."

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

**"Isn't this just another schema library, like moon_zod or moonschema?"**
> "Those judge a *value* — you hand them an instance and they say yes or no. This judges the *model*, statically, with no data at all: is the constraint system satisfiable, do two versions stay compatible, did the projection drop anything, does the definition survive the round-trip. And I'm not claiming they are wrong — `moonmodel`, the library I build on, writes `minimum: 0` next to `maximum: -1` and emits a schema no value can satisfy. The demo shows that side by side. The ecosystem generates; this verifies."

**"Isn't the projection just moonmodel?"**
> "Four of the seven targets are — that is deliberate, I don't rebuild what exists. The TypeScript / Zod / Prisma emitters are mine, and that does overlap a generic code generator; I'm not going to pretend otherwise. They are mine because they have to understand model semantics, and they sit behind a trait so a model-aware emitter could replace them. The five engines are the product, and none of them is a projection."

**"Then why write a custom modeling language?"**
> "For exactly one reason: a field's constraint has to be able to reference another field's constraint — `b: Int [over=a.least]`. In JSON Schema or Zod a constraint is a constant hanging off one field, so there is nowhere to put 'a constraint that depends on another constraint'. Cross-field satisfiability needs a notation that can say it. Everything else I reuse: model data structures and four projection backends from `moonmodel`, runtime validation from libraries like `moon_zod`."

**"What did you build that Prisma/Drizzle don't?"**
> "They generate code from a model. This one reasons about the model: whether its constraints are satisfiable, whether two versions are compatible, what SQL migration a change implies, and whether it survives a round-trip."

**"Why MoonBit for this?"**
> "The kernel compiles to wasm-gc and runs entirely in the browser — one binary, no server. The pattern matching and ADT support made the compiler frontend and type-equivalence engine direct rather than ceremony."

**"How do you know it works?"**
> "251 MoonBit tests, 16 of them property-based — a deterministic PRNG generates random models and asserts 12 invariants like round-trip preservation and diff symmetry. Plus 26 frontend tests that load the real WASM binary and 4 that render the workbench to check all seven panels."
