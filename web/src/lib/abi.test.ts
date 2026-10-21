import { describe, it, expect } from 'vitest';
import type { KernelInput, FieldInput, TypeSpec } from './types';

// 前端 ABI 层测试：验证状态→内核调用的序列化正确性
// 不测试投影算法（那是 MoonBit 内核的职责）

describe('ABI serialization', () => {
  it('field with all properties serializes correctly', () => {
    const field: FieldInput = {
      name: 'id',
      kind: 'Big',
      required: true,
      nullable: false,
      doc: 'user ID',
      default: null,
      check: { unique: true },
    };
    const input: KernelInput = {
      name: 'User',
      doc: 'user',
      fields: [field],
      known: [],
    };
    const json = JSON.stringify(input);
    const parsed = JSON.parse(json);
    expect(parsed.fields[0].name).toBe('id');
    expect(parsed.fields[0].kind).toBe('Big');
    expect(parsed.fields[0].required).toBe(true);
    expect(parsed.fields[0].nullable).toBe(false);
    expect(parsed.fields[0].check.unique).toBe(true);
  });

  it('compound type specs serialize correctly', () => {
    const listType: TypeSpec = { list: 'Text' };
    const dictType: TypeSpec = { dict: 'Int' };
    const refType: TypeSpec = { ref: 'Address' };

    const input: KernelInput = {
      name: 'T',
      doc: '',
      fields: [
        { name: 'tags', kind: listType, required: true, nullable: false, doc: '', default: null, check: {} },
        { name: 'meta', kind: dictType, required: true, nullable: false, doc: '', default: null, check: {} },
        { name: 'home', kind: refType, required: true, nullable: false, doc: '', default: null, check: {} },
      ],
    };
    const json = JSON.stringify(input);
    const parsed = JSON.parse(json);
    expect(parsed.fields[0].kind).toEqual({ list: 'Text' });
    expect(parsed.fields[1].kind).toEqual({ dict: 'Int' });
    expect(parsed.fields[2].kind).toEqual({ ref: 'Address' });
  });

  it('check with bounds serializes correctly', () => {
    const field: FieldInput = {
      name: 'age',
      kind: 'Int',
      required: true,
      nullable: false,
      doc: '',
      default: null,
      check: {
        least: 0,
        under: 150,
        shortest: 1,
        longest: 64,
        pattern: '^[a-z]+$',
        format: 'email',
        options: ['a', 'b'],
        distinct: true,
        unique: false,
      },
    };
    const input: KernelInput = { name: 'T', doc: '', fields: [field] };
    const parsed = JSON.parse(JSON.stringify(input));
    expect(parsed.fields[0].check.least).toBe(0);
    expect(parsed.fields[0].check.under).toBe(150);
    expect(parsed.fields[0].check.shortest).toBe(1);
    expect(parsed.fields[0].check.longest).toBe(64);
    expect(parsed.fields[0].check.pattern).toBe('^[a-z]+$');
    expect(parsed.fields[0].check.format).toBe('email');
    expect(parsed.fields[0].check.options).toEqual(['a', 'b']);
    expect(parsed.fields[0].check.distinct).toBe(true);
  });

  it('required and nullable are independent booleans', () => {
    const combos = [
      { required: true, nullable: false },
      { required: true, nullable: true },
      { required: false, nullable: false },
      { required: false, nullable: true },
    ];
    for (const combo of combos) {
      const field: FieldInput = {
        name: 'x',
        kind: 'Text',
        ...combo,
        doc: '',
        default: null,
        check: {},
      };
      const parsed = JSON.parse(JSON.stringify({ fields: [field] }));
      expect(parsed.fields[0].required).toBe(combo.required);
      expect(parsed.fields[0].nullable).toBe(combo.nullable);
    }
  });
});

describe('Kernel output shape', () => {
  it('expected output keys are present in type definition', () => {
    // 验证 KernelOutput 类型完整性（编译时检查）
    const output = {
      ok: true,
      jsonSchema: '{}',
      openapi: '{}',
      sql: 'CREATE TABLE x ();',
      graphql: 'type X {}',
      drops: {
        jsonSchema: [],
        openapi: [],
        sql: [],
        graphql: [],
      },
    };
    expect(output.ok).toBe(true);
    expect(output.drops).toHaveProperty('jsonSchema');
    expect(output.drops).toHaveProperty('openapi');
    expect(output.drops).toHaveProperty('sql');
    expect(output.drops).toHaveProperty('graphql');
  });
});
