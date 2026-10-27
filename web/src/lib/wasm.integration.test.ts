import { describe, it, expect, beforeAll } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Integration tests against the real MoonBit WASM kernel
// These verify the five engines actually work end-to-end through the ABI

interface Kernel {
  project_from_json(input: string): string;
  get_presets_json(): string;
  dsl_project(dsl: string): string;
  solve_constraints(model_json: string): string;
  generate_migration(old_json: string, new_json: string): string;
  check_equivalence(a_json: string, b_json: string): string;
}

let kernel: Kernel;
let wasmGcSupported = true;

beforeAll(async () => {
  const wasmPath = resolve(__dirname, '../../public/projdesk.wasm');
  const bytes = readFileSync(wasmPath);
  try {
    const { instance } = await (WebAssembly as unknown as {
      instantiate(
        bytes: BufferSource,
        imports: WebAssembly.Imports,
        options: { builtins: string[]; importedStringConstants: string },
      ): Promise<WebAssembly.WebAssemblyInstantiatedSource>;
    }).instantiate(bytes, {} as WebAssembly.Imports, {
      builtins: ['js-string'],
      importedStringConstants: '_',
    });
    kernel = instance.exports as unknown as Kernel;
  } catch (e) {
    // The kernel is compiled with wasm-gc. Older Node runtimes cannot
    // instantiate it; skip rather than fail the whole suite.
    wasmGcSupported = false;
    console.warn('wasm-gc not supported in this runtime, skipping integration tests');
  }
});

describe.skipIf(!wasmGcSupported)('Engine 1: DSL Compiler (real WASM)', () => {
  it('parses a simple model into projections', () => {
    const result = JSON.parse(kernel.dsl_project('model User {\n  id: Big @unique\n  name: Text [longest=64]\n}'));
    expect(result.jsonSchema).toContain('"User"');
    expect(result.jsonSchema).toContain('maxLength');
    expect(result.sql).toContain('CREATE TABLE');
  });

  it('parses compound types', () => {
    const result = JSON.parse(kernel.dsl_project('model T {\n  tags: List(Text)\n  home: Ref(Address)\n}'));
    expect(result.jsonSchema).toContain('array');
    expect(result.graphql).toContain('Address');
  });

  it('parses multiple models', () => {
    const result = JSON.parse(kernel.dsl_project('model A {\n  x: Text\n}\n\nmodel B {\n  y: Int\n}'));
    expect(result.jsonSchema).toContain('"A"');
  });

  it('reports errors for invalid DSL instead of crashing', () => {
    // Invalid DSL should either produce empty output or a minimal valid object,
    // but must never throw or return malformed JSON
    const raw = kernel.dsl_project('this is not valid dsl {{{');
    expect(() => JSON.parse(raw)).not.toThrow();
    const result = JSON.parse(raw);
    // If parsing failed, projections are empty
    if (!result.jsonSchema) {
      expect(result.jsonSchema).toBe('');
    }
  });
});

describe.skipIf(!wasmGcSupported)('Engine 2: Constraint Solver (real WASM)', () => {
  const modelWith = (check: object) => JSON.stringify({
    name: 'T', doc: '', fields: [{
      name: 'x', kind: 'Real', required: true, nullable: false, doc: '', default: null, check,
    }],
  });

  it('detects empty range conflict', () => {
    const result = JSON.parse(kernel.solve_constraints(modelWith({ least: 10, most: 5 })));
    expect(result.conflict_count).toBe(1);
    expect(result.diagnoses[0].severity).toBe('error');
    expect(result.diagnoses[0].text).toContain('empty range');
  });

  it('detects length conflict', () => {
    const result = JSON.parse(kernel.solve_constraints(modelWith({ shortest: 10, longest: 5 })));
    expect(result.conflict_count).toBe(1);
  });

  it('reports no conflicts for valid constraints', () => {
    const result = JSON.parse(kernel.solve_constraints(modelWith({ least: 0, most: 100 })));
    expect(result.conflict_count).toBe(0);
  });

  it('detects redundancy (least subsumed by over)', () => {
    const result = JSON.parse(kernel.solve_constraints(modelWith({ least: 0, over: 5 })));
    expect(result.redundant_count).toBeGreaterThan(0);
  });
});

describe.skipIf(!wasmGcSupported)('Engine 3: Migration Engine (real WASM)', () => {
  const model = (fields: object[]) => JSON.stringify({ name: 'T', doc: '', fields });

  it('detects field addition', () => {
    const oldM = model([{ name: 'a', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const newM = model([
      { name: 'a', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} },
      { name: 'b', kind: 'Int', required: true, nullable: false, doc: '', default: null, check: {} },
    ]);
    const result = JSON.parse(kernel.generate_migration(oldM, newM));
    expect(result.changes.length).toBe(1);
    expect(result.sql).toContain('ADD COLUMN');
  });

  it('detects field removal as breaking', () => {
    const oldM = model([
      { name: 'a', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} },
      { name: 'b', kind: 'Int', required: true, nullable: false, doc: '', default: null, check: {} },
    ]);
    const newM = model([{ name: 'a', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const result = JSON.parse(kernel.generate_migration(oldM, newM));
    expect(result.breaking_count).toBe(1);
    expect(result.sql).toContain('DROP COLUMN');
  });

  it('detects type change', () => {
    const oldM = model([{ name: 'a', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const newM = model([{ name: 'a', kind: 'Big', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const result = JSON.parse(kernel.generate_migration(oldM, newM));
    expect(result.breaking_count).toBe(1);
  });
});

describe.skipIf(!wasmGcSupported)('Engine 4: Equivalence Checker (real WASM)', () => {
  const model = (fields: object[]) => JSON.stringify({ name: 'T', doc: '', fields });

  it('identical models are equivalent', () => {
    const m = model([{ name: 'a', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const result = JSON.parse(kernel.check_equivalence(m, m));
    expect(result.equivalent).toBe(true);
  });

  it('Int model is subtype of Big model', () => {
    const strict = model([{ name: 'a', kind: 'Int', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const loose = model([{ name: 'a', kind: 'Big', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const result = JSON.parse(kernel.check_equivalence(strict, loose));
    expect(result.equivalent).toBe(false);
    expect(result.result).toContain('subtype');
  });

  it('different field sets are incompatible', () => {
    const a = model([{ name: 'x', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const b = model([{ name: 'y', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }]);
    const result = JSON.parse(kernel.check_equivalence(a, b));
    expect(result.equivalent).toBe(false);
    expect(result.result).toContain('incompatible');
  });
});

describe.skipIf(!wasmGcSupported)('Projection still works (regression)', () => {
  it('project_from_json returns all seven outputs', () => {
    const input = JSON.stringify({
      name: 'User', doc: '',
      fields: [{ name: 'id', kind: 'Big', required: true, nullable: false, doc: '', default: null, check: { unique: true } }],
    });
    const result = JSON.parse(kernel.project_from_json(input));
    for (const key of ['jsonSchema', 'openapi', 'sql', 'graphql', 'typescript', 'zod', 'prisma']) {
      expect(result[key]).toBeTruthy();
    }
    expect(result.drops.jsonSchema.length).toBe(1);
  });
});
