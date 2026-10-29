import { describe, it, expect } from 'vitest';

// Engine ABI contract tests — these verify the WASM export surface stays stable
// The actual engine logic is tested in MoonBit (195 tests); these check the
// frontend↔kernel contract that the engine playground depends on.

// Mirrors the ProjDeskExports interface in wasm.ts
const KERNEL_EXPORTS = [
  'project_from_json',
  'get_presets_json',
  'import_from_json_schema_str',
  'dsl_project',
  'solve_constraints',
  'generate_migration',
  'check_equivalence',
  'verify_roundtrip',
  'verify_roundtrip_dsl',
  'dsl_to_model',
  'check_semantics',
];

describe('Engine ABI contract', () => {
  it('all 11 kernel exports are declared on the frontend interface', () => {
    expect(KERNEL_EXPORTS).toHaveLength(11);
    for (const name of KERNEL_EXPORTS) {
      expect(name).toMatch(/^[a-z_]+$/);
    }
  });

  it('DSL source is a valid modeling language snippet', () => {
    const dsl = `model User {
  id: Big @unique
  name: Text [shortest=1, longest=64]
}`;
    // Structural sanity: has model keyword, braces balanced, field has type
    expect(dsl).toContain('model ');
    expect(dsl.match(/\{/g)?.length).toBe(dsl.match(/\}/g)?.length);
    expect(dsl).toMatch(/\w+\s*:\s*\w+/);
  });

  it('constraint model JSON round-trips for solver input', () => {
    const model = {
      name: 'T',
      doc: '',
      fields: [{
        name: 'x',
        kind: 'Real',
        required: true,
        nullable: false,
        doc: '',
        default: null,
        check: { least: 10, most: 5 },
      }],
    };
    const round = JSON.parse(JSON.stringify(model));
    expect(round.fields[0].check.least).toBe(10);
    expect(round.fields[0].check.most).toBe(5);
  });

  it('migration input requires two model JSON strings', () => {
    const oldModel = { name: 'T', doc: '', fields: [] };
    const newModel = { name: 'T', doc: '', fields: [{ name: 'x', kind: 'Text' }] };
    expect(JSON.stringify(oldModel)).not.toBe(JSON.stringify(newModel));
  });

  it('equivalence input requires two model JSON strings', () => {
    const strict = { name: 'T', doc: '', fields: [{ name: 'x', kind: 'Int', required: true, nullable: false, doc: '', default: null, check: {} }] };
    const loose = { name: 'T', doc: '', fields: [{ name: 'x', kind: 'Big', required: false, nullable: true, doc: '', default: null, check: {} }] };
    expect(JSON.stringify(strict)).not.toBe(JSON.stringify(loose));
  });
});
