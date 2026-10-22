# ProjDesk 3-Minute Demo Script

## Opening (20s)

> "I'm ProjDesk — One Definition, Four Projections. When you need to declare a business object, you shouldn't write four schemas. Say it once here, and see all four worlds at the same time."

**Show the three product principles** (speak them):
1. One source of truth, four projections — all algorithms in the MoonBit kernel
2. Honest projection — what doesn't fit is shown as "dropped + reason"
3. Demo first — edit once, all four panels update together

---

## Climax 1: Open User preset, change longest (40s)

1. Open the page -> User preset loads automatically, four panels have output
2. Find the `name` field's constraint panel
3. Change `longest` from **64** to **32**
4. **Point at the four panels**:
   - JSON Schema: `"maxLength": 32`
   - OpenAPI: same
   - SQL: `CHECK (length(name) <= 32)`
   - GraphQL: **unchanged** (drop report lights up: "GraphQL cannot carry length constraints")

> "Edit one place, four panels update together. GraphQL can't carry it? It honestly tells you."

---

## Climax 2: Enable id.unique (30s)

1. Find the `id` field
2. Check `unique`
3. **Point at results**:
   - SQL: `UNIQUE` appears
   - JSON Schema / OpenAPI / GraphQL: drop reports light up with different reasons

> "SQL carries it. The other three honestly say they can't — with different reasons."

---

## Climax 3: Toggle required / nullable (30s)

1. Select `avatar` field (currently: required=false, nullable=true)
2. Check `required`, then uncheck `nullable`
3. **Point at four-panel differences**:
   - JSON Schema: `"required"` array gains `avatar`; type no longer `["string","null"]`
   - OpenAPI: `"nullable": false`
   - SQL: `NOT NULL` appears
   - GraphQL: `!` appears

> "required and nullable are two independent switches — each target has different semantics. That's why one definition, four projections."

---

## Climax 4: Run moon test (30s)

1. Switch to terminal
2. `cd moonbit && moon test`
3. Show **78 tests all green**
4. (Optional) `moon build --target wasm-gc --release`

> "Projection algorithms live in MoonBit, contract tests lock semantics, the repo is reproducible."

---

## Wrap-up (20s)

> "ProjDesk: metadata/contract layer, one description, multiple projections. Not an ORM, not a migrator, not a GraphQL server — just helps you say it clearly in four worlds."

**Optional bonus**: Show the Projector trait extension point, DropReason types, wasm ABI comments.
