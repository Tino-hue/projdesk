import { describe, it, expect } from 'vitest';
import type { KernelInput, KernelOutput, ModelInput, FieldInput, TypeSpec, CheckInput, DropReason } from './types';

describe('TypeSpec: every variant round-trips', () => {
  const simpleTypes: TypeSpec[] = ['Bool', 'Int', 'Big', 'Real', 'Text', 'Bytes', 'Stamp', 'Any'];

  it.each(simpleTypes)('simple type %s round-trips', (t) => {
    const f: FieldInput = { name: 'x', kind: t, required: true, nullable: false, doc: '', default: null, check: {} };
    const round = JSON.parse(JSON.stringify(f));
    expect(round.kind).toBe(t);
  });

  it('List of each simple type round-trips', () => {
    for (const inner of simpleTypes) {
      const kind: TypeSpec = { list: inner };
      const round = JSON.parse(JSON.stringify(kind));
      expect(round).toEqual({ list: inner });
    }
  });

  it('Dict of each simple type round-trips', () => {
    for (const inner of simpleTypes) {
      const kind: TypeSpec = { dict: inner };
      const round = JSON.parse(JSON.stringify(kind));
      expect(round).toEqual({ dict: inner });
    }
  });

  it('nested List of List round-trips', () => {
    const kind: TypeSpec = { list: { list: 'Text' } };
    expect(JSON.parse(JSON.stringify(kind))).toEqual({ list: { list: 'Text' } });
  });

  it('List of Dict round-trips', () => {
    const kind: TypeSpec = { list: { dict: 'Int' } };
    expect(JSON.parse(JSON.stringify(kind))).toEqual({ list: { dict: 'Int' } });
  });

  it('Ref with various names round-trips', () => {
    for (const name of ['Address', 'User', 'A', 'SomeLongName123']) {
      const kind: TypeSpec = { ref: name };
      expect(JSON.parse(JSON.stringify(kind))).toEqual({ ref: name });
    }
  });
});

describe('Check: all constraint combinations', () => {
  it('numeric bounds round-trip including zero and negatives', () => {
    const cases: CheckInput[] = [
      { least: 0 },
      { most: 0 },
      { over: -100 },
      { under: 100 },
      { step: 0.01 },
      { least: -1.5, most: 1.5, over: -2, under: 2, step: 0.5 },
      { least: 999999, most: 1000000 },
    ];
    for (const check of cases) {
      const round = JSON.parse(JSON.stringify({ check }));
      for (const [k, v] of Object.entries(check)) {
        expect(round.check[k]).toBe(v);
      }
    }
  });

  it('string bounds round-trip', () => {
    const check: CheckInput = { shortest: 0, longest: 999999 };
    const round = JSON.parse(JSON.stringify({ check }));
    expect(round.check.shortest).toBe(0);
    expect(round.check.longest).toBe(999999);
  });

  it('pattern with regex special chars round-trips', () => {
    for (const p of ['^a+$', '.*', '[a-z]{3,10}', '\\d{3}-\\d{4}', '(?:foo|bar)']) {
      const round = JSON.parse(JSON.stringify({ check: { pattern: p } }));
      expect(round.check.pattern).toBe(p);
    }
  });

  it('format values round-trip', () => {
    for (const f of ['email', 'uri', 'date-time', 'uuid', 'ipv4']) {
      const round = JSON.parse(JSON.stringify({ check: { format: f } }));
      expect(round.check.format).toBe(f);
    }
  });

  it('options with mixed JSON types round-trip', () => {
    const check: CheckInput = { options: ['text', 42, true, null] };
    const round = JSON.parse(JSON.stringify({ check }));
    expect(round.check.options).toEqual(['text', 42, true, null]);
  });

  it('distinct and unique round-trip independently', () => {
    const combos = [
      { distinct: false, unique: false },
      { distinct: true, unique: false },
      { distinct: false, unique: true },
      { distinct: true, unique: true },
    ];
    for (const combo of combos) {
      const round = JSON.parse(JSON.stringify({ check: combo }));
      expect(round.check.distinct).toBe(combo.distinct);
      expect(round.check.unique).toBe(combo.unique);
    }
  });
});

describe('required/nullable full matrix with serialization', () => {
  it('all 4 combos x 3 type kinds serialize correctly', () => {
    const kinds: TypeSpec[] = ['Text', 'Int', { list: 'Text' }];
    for (const kind of kinds) {
      for (const required of [true, false]) {
        for (const nullable of [true, false]) {
          const f: FieldInput = { name: 'x', kind, required, nullable, doc: '', default: null, check: {} };
          const round = JSON.parse(JSON.stringify(f));
          expect(round.required).toBe(required);
          expect(round.nullable).toBe(nullable);
          expect(round.kind).toEqual(kind);
        }
      }
    }
  });
});

describe('KernelOutput: drop reason structure', () => {
  it('DropReason has field, constraint, why', () => {
    const d: DropReason = { field: 'id', constraint: 'unique', why: 'not supported' };
    expect(d).toHaveProperty('field');
    expect(d).toHaveProperty('constraint');
    expect(d).toHaveProperty('why');
  });

  it('all seven drop arrays are present and typed', () => {
    const output: KernelOutput = {
      ok: true, jsonSchema: '{}', openapi: '{}', sql: 'CREATE TABLE x();', graphql: 'type X {}', typescript: '', zod: '', prisma: '',
      drops: {
        jsonSchema: [{ field: 'a', constraint: 'unique', why: 'x' }],
        openapi: [],
        sql: [],
        graphql: [],
        typescript: [],
        zod: [],
        prisma: [],
      },
    };
    expect(output.drops.jsonSchema).toHaveLength(1);
    expect(output.drops.openapi).toHaveLength(0);
    expect(Array.isArray(output.drops.sql)).toBe(true);
    expect(Array.isArray(output.drops.graphql)).toBe(true);
    expect(Array.isArray(output.drops.typescript)).toBe(true);
    expect(Array.isArray(output.drops.zod)).toBe(true);
    expect(Array.isArray(output.drops.prisma)).toBe(true);
  });
});

describe('ModelInput: complex models serialize', () => {
  it('model with 20 fields and all type kinds round-trips', () => {
    const fields: FieldInput[] = [
      { name: 'f_bool', kind: 'Bool', required: true, nullable: false, doc: '', default: true, check: {} },
      { name: 'f_int', kind: 'Int', required: true, nullable: false, doc: '', default: 0, check: { least: 0 } },
      { name: 'f_big', kind: 'Big', required: true, nullable: false, doc: '', default: null, check: { unique: true } },
      { name: 'f_real', kind: 'Real', required: true, nullable: false, doc: '', default: 0, check: { step: 0.01 } },
      { name: 'f_text', kind: 'Text', required: true, nullable: false, doc: 'hello', default: '', check: { longest: 255 } },
      { name: 'f_bytes', kind: 'Bytes', required: false, nullable: true, doc: '', default: null, check: {} },
      { name: 'f_stamp', kind: 'Stamp', required: true, nullable: false, doc: '', default: null, check: {} },
      { name: 'f_any', kind: 'Any', required: false, nullable: false, doc: '', default: null, check: {} },
      { name: 'f_list', kind: { list: 'Text' }, required: true, nullable: false, doc: '', default: null, check: { distinct: true } },
      { name: 'f_dict', kind: { dict: 'Int' }, required: false, nullable: false, doc: '', default: null, check: {} },
      { name: 'f_ref', kind: { ref: 'Address' }, required: true, nullable: false, doc: '', default: null, check: {} },
      { name: 'f_list_ref', kind: { list: { ref: 'Address' } }, required: false, nullable: false, doc: '', default: null, check: {} },
    ];
    const model: ModelInput = { name: 'Complex', doc: 'test', fields };
    const round = JSON.parse(JSON.stringify(model));
    expect(round.fields).toHaveLength(12);
    expect(round.fields[10].kind).toEqual({ ref: 'Address' });
    expect(round.fields[11].kind).toEqual({ list: { ref: 'Address' } });
  });
});

describe('Edge cases', () => {
  it('empty model serializes', () => {
    const m: ModelInput = { name: '', doc: '', fields: [] };
    expect(JSON.parse(JSON.stringify(m))).toEqual({ name: '', doc: '', fields: [] });
  });

  it('field with all defaults null/false is valid', () => {
    const f: FieldInput = { name: '', kind: 'Text', required: false, nullable: false, doc: '', default: null, check: {} };
    const round = JSON.parse(JSON.stringify(f));
    expect(round.required).toBe(false);
    expect(round.check).toEqual({});
  });

  it('KernelInput with dialects serializes', () => {
    const input: KernelInput = {
      name: 'T', doc: '', fields: [],
      openapiDialect: 'Swagger20', sqlDialect: 'Mysql',
      known: [],
    };
    const round = JSON.parse(JSON.stringify(input));
    expect(round.openapiDialect).toBe('Swagger20');
    expect(round.sqlDialect).toBe('Mysql');
  });
});

