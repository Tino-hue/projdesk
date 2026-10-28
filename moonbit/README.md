# ProjDesk MoonBit Kernel

The algorithm core of [ProjDesk](https://github.com/Tino-hue/projdesk) — a model
engineering workbench. One model description, five independent algorithm
engines, seven projection targets.

## Engines

| Engine | Modules | What it does |
|--------|---------|--------------|
| DSL compiler | `dsl_lexer` `dsl_parser` `dsl_expr` `dsl_codegen` `dsl_printer` `dsl_semantic` `dsl_resolve` | Hand-written lexer, recursive descent parser, constraint-expression evaluator, AST codegen, inverse AST printer, semantic checks, cross-field bound resolution |
| Constraint solver | `solver` `solver_propagate` | Conflict / redundancy / containment analysis, cross-field bound resolution, fixed-point interval propagation, reference-cycle detection |
| Migration engine | `migration` | Structured semantic diff, SQL `ALTER TABLE`, breaking-change classification |
| Equivalence checker | `equiv` | Type subtyping, constraint containment, version compatibility |
| Round-trip verifier | `roundtrip` | Formal generate-parse-compare correctness verification |

## Scope

This package provides the kernel. Projection formats (JSON Schema, OpenAPI,
SQL DDL, GraphQL SDL) come from
[moonbitstack/moonmodel](https://github.com/moonbitstack/moonmodel); TypeScript,
Zod and Prisma emitters live in `main/codegen.mbt`.

## Build

```bash
moon build --target wasm-gc --release
moon test
```

## License

MIT — see the repository root for the full text.
