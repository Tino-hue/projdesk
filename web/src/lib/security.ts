// Input validation: sanitize all external data (localStorage, URL hash, file import)

import type { ModelInput, FieldInput, TypeSpec, CheckInput } from './types';

import { MODEL_TYPES, OPENAPI_DIALECTS, SQL_DIALECTS, LIMITS } from './constants';

const VALID_TYPES: Set<string> = new Set(MODEL_TYPES);
const VALID_OPENAPI: Set<string> = new Set(OPENAPI_DIALECTS);
const VALID_SQL: Set<string> = new Set(SQL_DIALECTS);

const MAX_FIELD_NAME = LIMITS.MAX_FIELD_NAME;
const MAX_DOC = LIMITS.MAX_DOC;
const MAX_FIELDS = LIMITS.MAX_FIELDS;
const MAX_PATTERN = LIMITS.MAX_PATTERN;
const MAX_OPTIONS = LIMITS.MAX_OPTIONS;

function safeString(v: unknown, maxLen: number): string {
  if (typeof v !== 'string') return '';
  // Strip control characters (0x00-0x1F, 0x7F)
  let out = '';
  for (let i = 0; i < v.length && out.length < maxLen; i++) {
    const code = v.charCodeAt(i);
    if (code >= 0x20 && code !== 0x7F) out += v[i];
  }
  return out;
}

function validateTypeSpec(v: unknown, depth = 0): TypeSpec {
  if (depth > 5) return 'Any';
  if (typeof v === 'string') {
    return VALID_TYPES.has(v) ? (v as TypeSpec) : 'Text';
  }
  if (v && typeof v === 'object') {
    const obj = v as Record<string, unknown>;
    if ('list' in obj) return { list: validateTypeSpec(obj.list, depth + 1) };
    if ('dict' in obj) return { dict: validateTypeSpec(obj.dict, depth + 1) };
    if ('ref' in obj) return { ref: safeString(obj.ref, 100) };
    if ('nest' in obj) return { nest: validateModel(obj.nest, depth + 1) };
  }
  return 'Any';
}

function validateCheck(v: unknown): CheckInput {
  if (!v || typeof v !== 'object') return {};
  const obj = v as Record<string, unknown>;
  const result: CheckInput = {};
  const numKeys = ['least', 'most', 'over', 'under', 'step'] as const;
  for (const k of numKeys) {
    const val = obj[k];
    if (typeof val === 'number' && isFinite(val)) result[k] = val;
  }
  const intKeys = ['shortest', 'longest'] as const;
  for (const k of intKeys) {
    const val = obj[k];
    if (typeof val === 'number' && isFinite(val) && val >= 0 && val <= 1000000) {
      result[k] = Math.floor(val);
    }
  }
  if (typeof obj.pattern === 'string') result.pattern = safeString(obj.pattern, MAX_PATTERN);
  if (typeof obj.format === 'string') result.format = safeString(obj.format, 50);
  if (Array.isArray(obj.options)) {
    result.options = obj.options.slice(0, MAX_OPTIONS).map((o) => {
      if (typeof o === 'string') return safeString(o, 500);
      if (typeof o === 'number' && isFinite(o)) return o;
      if (typeof o === 'boolean') return o;
      return null;
    });
  }
  if (obj.distinct === true) result.distinct = true;
  if (obj.unique === true) result.unique = true;
  return result;
}

function validateField(v: unknown, depth = 0): FieldInput {
  const obj = (v && typeof v === 'object' ? v : {}) as Record<string, unknown>;
  return {
    name: safeString(obj.name, MAX_FIELD_NAME),
    kind: validateTypeSpec(obj.kind, depth),
    required: obj.required !== false,
    nullable: obj.nullable === true,
    doc: safeString(obj.doc, MAX_DOC),
    default: null,
    check: validateCheck(obj.check),
  };
}

export function validateModel(v: unknown, depth = 0): ModelInput {
  if (!v || typeof v !== 'object' || depth > 5) {
    return { name: '', doc: '', fields: [] };
  }
  const obj = v as Record<string, unknown>;
  const fields = Array.isArray(obj.fields) ? obj.fields : [];
  return {
    name: safeString(obj.name, 200),
    doc: safeString(obj.doc, MAX_DOC),
    fields: fields.slice(0, MAX_FIELDS).map((f) => validateField(f, depth + 1)),
  };
}

export function validateKernelInput(v: unknown) {
  const obj = (v && typeof v === 'object' ? v : {}) as Record<string, unknown>;
  return {
    model: validateModel(obj),
    known: Array.isArray(obj.known)
      ? (obj.known as unknown[]).slice(0, 50).map((m) => validateModel(m, 1))
      : [],
    openapiDialect: VALID_OPENAPI.has(obj.openapiDialect as string)
      ? (obj.openapiDialect as string) : 'OpenApi30',
    sqlDialect: VALID_SQL.has(obj.sqlDialect as string)
      ? (obj.sqlDialect as string) : 'Postgres',
  };
}

export function safeDecodeHash(hash: string): ReturnType<typeof validateKernelInput> | null {
  if (!hash || hash.length > 500000) return null;
  try {
    const json = decodeURIComponent(atob(hash));
    if (json.length > 1000000) return null;
    return validateKernelInput(JSON.parse(json));
  } catch {
    return null;
  }
}

export function safeLoadState(raw: string | null): { models: ModelInput[]; activeId: string } | null {
  if (!raw || raw.length > 5000000) return null;
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed.models) || parsed.models.length === 0) return null;
    if (parsed.models.length > 50) return null;
    return {
      models: parsed.models.map((m: unknown) => {
        const obj = (m && typeof m === 'object' ? m : {}) as Record<string, unknown>;
        return validateModel(obj.model ?? obj);
      }),
      activeId: safeString(parsed.activeId, 50),
    };
  } catch {
    return null;
  }
}

export function escapeSqlIdent(name: string): string {
  return name.replace(/[^a-zA-Z0-9_]/g, '_').slice(0, 100);
}

export function escapeSqlLiteral(value: string): string {
  return value.replace(/'/g, "''").slice(0, 10000);
}


