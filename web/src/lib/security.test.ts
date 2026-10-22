import { describe, it, expect } from 'vitest';
import { validateKernelInput, safeDecodeHash, safeLoadState, escapeSqlIdent, escapeSqlLiteral, validateModel } from './security';

describe('Input validation', () => {
  it('rejects non-object input', () => {
    const result = validateKernelInput('not an object');
    expect(result.model.name).toBe('');
    expect(result.model.fields).toHaveLength(0);
  });

  it('limits field name length', () => {
    const longName = 'a'.repeat(5000);
    const result = validateKernelInput({
      name: 'T',
      fields: [{ name: longName, kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }],
    });
    expect(result.model.fields[0].name.length).toBeLessThanOrEqual(200);
  });

  it('limits field count', () => {
    const fields = Array.from({ length: 1000 }, (_, i) => ({
      name: 'f' + i, kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {},
    }));
    const result = validateKernelInput({ name: 'T', fields });
    expect(result.model.fields.length).toBeLessThanOrEqual(500);
  });

  it('validates type spec and falls back to Text', () => {
    const result = validateKernelInput({
      name: 'T',
      fields: [
        { name: 'a', kind: 'InvalidType', required: true, nullable: false, doc: '', default: null, check: {} },
        { name: 'b', kind: { list: 'Text' }, required: true, nullable: false, doc: '', default: null, check: {} },
      ],
    });
    expect(result.model.fields[0].kind).toBe('Text');
    expect(result.model.fields[1].kind).toEqual({ list: 'Text' });
  });

  it('validates dialect values', () => {
    const result = validateKernelInput({ name: 'T', fields: [], openapiDialect: 'Invalid', sqlDialect: 'HACKED' });
    expect(result.openapiDialect).toBe('OpenApi30');
    expect(result.sqlDialect).toBe('Postgres');
  });

  it('limits options array size', () => {
    const options = Array.from({ length: 1000 }, (_, i) => 'opt' + i);
    const result = validateKernelInput({
      name: 'T',
      fields: [{ name: 'a', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: { options } }],
    });
    expect(result.model.fields[0].check.options!.length).toBeLessThanOrEqual(100);
  });

  it('rejects non-finite numbers', () => {
    const result = validateKernelInput({
      name: 'T',
      fields: [{ name: 'a', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: { least: NaN, most: Infinity } }],
    });
    expect(result.model.fields[0].check.least).toBeUndefined();
    expect(result.model.fields[0].check.most).toBeUndefined();
  });
});

describe('URL hash safety', () => {
  it('rejects oversized hash', () => {
    expect(safeDecodeHash('A'.repeat(600000))).toBeNull();
  });

  it('rejects invalid base64', () => {
    expect(safeDecodeHash('not-base64!!!')).toBeNull();
  });

  it('rejects empty hash', () => {
    expect(safeDecodeHash('')).toBeNull();
  });

  it('accepts valid hash', () => {
    const hash = btoa(encodeURIComponent(JSON.stringify({ name: 'User', doc: '', fields: [] })));
    const result = safeDecodeHash(hash);
    expect(result).not.toBeNull();
    expect(result!.model.name).toBe('User');
  });
});

describe('localStorage safety', () => {
  it('rejects invalid JSON', () => {
    expect(safeLoadState('not json')).toBeNull();
  });

  it('rejects too many models', () => {
    const models = Array.from({ length: 100 }, () => ({ model: { name: 'x', fields: [] } }));
    expect(safeLoadState(JSON.stringify({ models, activeId: 'm1' }))).toBeNull();
  });

  it('accepts valid state', () => {
    const result = safeLoadState(JSON.stringify({ models: [{ model: { name: 'User', fields: [] } }], activeId: 'm1' }));
    expect(result).not.toBeNull();
    expect(result!.models[0].name).toBe('User');
  });
});

describe('SQL escaping', () => {
  it('escapes special characters in identifiers', () => {
    expect(escapeSqlIdent('normal_name')).toBe('normal_name');
    expect(escapeSqlIdent('name; DROP TABLE')).toContain('_');
    expect(escapeSqlIdent('name; DROP TABLE')).not.toContain(';');
  });

  it('limits identifier length', () => {
    expect(escapeSqlIdent('a'.repeat(500)).length).toBeLessThanOrEqual(100);
  });

  it('escapes SQL string literals', () => {
    expect(escapeSqlLiteral('normal')).toBe('normal');
    expect(escapeSqlLiteral("it's")).toBe("it''s");
    // Quote is escaped, so string injection via ' is neutralized
    expect(escapeSqlLiteral("a'b")).toBe("a''b");
    expect(escapeSqlLiteral("'")).toBe("''");
  });
});

describe('validateModel', () => {
  it('handles deeply nested models', () => {
    const deep = { name: 'x', doc: '', fields: [{ name: 'a', kind: { nest: { name: 'y', doc: '', fields: [{ name: 'b', kind: 'Text', required: true, nullable: false, doc: '', default: null, check: {} }] } }, required: true, nullable: false, doc: '', default: null, check: {} }] };
    const result = validateModel(deep);
    expect(result.fields.length).toBeGreaterThan(0);
  });
});
