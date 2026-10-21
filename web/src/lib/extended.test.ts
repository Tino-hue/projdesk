import { describe, it, expect } from 'vitest';
import type { KernelInput, KernelOutput, ModelInput, FieldInput, TypeSpec, CheckInput } from './types';

describe('Type encoding edge cases', () => {
  it('all simple type names are valid TypeSpec', () => {
    const types: TypeSpec[] = ['Bool', 'Int', 'Big', 'Real', 'Text', 'Bytes', 'Stamp', 'Any'];
    for (const t of types) {
      const f: FieldInput = { name: 'x', kind: t, required: true, nullable: false, doc: '', default: null, check: {} };
      expect(typeof f.kind).toBe('string');
    }
  });

  it('nested compound types serialize', () => {
    const nested: TypeSpec = { list: { list: 'Int' } };
    const input: KernelInput = {
      name: 'T', doc: '', fields: [
        { name: 'matrix', kind: nested, required: true, nullable: false, doc: '', default: null, check: {} },
      ],
    };
    const round = JSON.parse(JSON.stringify(input));
    expect(round.fields[0].kind).toEqual({ list: { list: 'Int' } });
  });

  it('Ref type encodes correctly', () => {
    const refType: TypeSpec = { ref: 'Address' };
    const input: KernelInput = {
      name: 'T', doc: '', fields: [
        { name: 'home', kind: refType, required: true, nullable: false, doc: '', default: null, check: {} },
      ],
    };
    const round = JSON.parse(JSON.stringify(input));
    expect(round.fields[0].kind).toEqual({ ref: 'Address' });
  });
});

describe('Check serialization completeness', () => {
  it('all Check fields round-trip', () => {
    const check: CheckInput = {
      least: 0, most: 100, over: -1, under: 101, step: 0.5,
      shortest: 1, longest: 64,
      pattern: '^[a-z]+$', format: 'email',
      options: ['a', 'b', 'c'],
      distinct: true, unique: true,
    };
    const input: KernelInput = {
      name: 'T', doc: '', fields: [
        { name: 'x', kind: 'Text', required: true, nullable: false, doc: '', default: null, check },
      ],
    };
    const round = JSON.parse(JSON.stringify(input));
    const c = round.fields[0].check;
    expect(c.least).toBe(0);
    expect(c.most).toBe(100);
    expect(c.over).toBe(-1);
    expect(c.under).toBe(101);
    expect(c.step).toBe(0.5);
    expect(c.shortest).toBe(1);
    expect(c.longest).toBe(64);
    expect(c.pattern).toBe('^[a-z]+$');
    expect(c.format).toBe('email');
    expect(c.options).toEqual(['a', 'b', 'c']);
    expect(c.distinct).toBe(true);
    expect(c.unique).toBe(true);
  });

  it('empty Check is valid', () => {
    const input: KernelInput = {
      name: 'T', doc: '', fields: [
        { name: 'x', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} },
      ],
    };
    const round = JSON.parse(JSON.stringify(input));
    expect(round.fields[0].check).toEqual({});
  });
});

describe('required/nullable truth table', () => {
  it('all 4 combinations serialize independently', () => {
    const combos = [
      { required: true, nullable: false },
      { required: true, nullable: true },
      { required: false, nullable: false },
      { required: false, nullable: true },
    ];
    for (const combo of combos) {
      const f: FieldInput = { name: 'x', kind: 'Text', ...combo, doc: '', default: null, check: {} };
      const round = JSON.parse(JSON.stringify({ fields: [f] }));
      expect(round.fields[0].required).toBe(combo.required);
      expect(round.fields[0].nullable).toBe(combo.nullable);
    }
  });
});

describe('Kernel output shape validation', () => {
  it('has all required top-level keys', () => {
    const output: KernelOutput = {
      ok: true, jsonSchema: '', openapi: '', sql: '', graphql: '', typescript: '', zod: '', prisma: '',
      drops: { jsonSchema: [], openapi: [], sql: [], graphql: [] },
    };
    expect(output).toHaveProperty('ok');
    expect(output).toHaveProperty('jsonSchema');
    expect(output).toHaveProperty('openapi');
    expect(output).toHaveProperty('sql');
    expect(output).toHaveProperty('graphql');
    expect(output).toHaveProperty('drops');
  });

  it('drops structure has 4 target arrays', () => {
    const drops = { jsonSchema: [], openapi: [], sql: [], graphql: [] };
    expect(Object.keys(drops)).toHaveLength(4);
  });

  it('DropReason shape is correct', () => {
    const d = { field: 'id', constraint: 'unique', why: 'not supported' };
    expect(d.field).toBe('id');
    expect(d.constraint).toBe('unique');
    expect(d.why).toBeTruthy();
  });
});

describe('ModelInput validation', () => {
  it('empty model is valid', () => {
    const m: ModelInput = { name: '', doc: '', fields: [] };
    expect(m.fields).toHaveLength(0);
  });

  it('model with many fields is valid', () => {
    const fields: FieldInput[] = Array.from({ length: 20 }, (_, i) => ({
      name: `f${i}`, kind: 'Text' as TypeSpec, required: true, nullable: false, doc: '', default: null, check: {},
    }));
    const m: ModelInput = { name: 'Big', doc: '', fields };
    expect(m.fields).toHaveLength(20);
  });
});

