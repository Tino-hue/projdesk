// Centralized constants: eliminate magic strings across the codebase

// SQL dialects
export const SQL_DIALECTS = ['Postgres', 'Sqlite', 'Mysql'] as const;
export type SqlDialectName = (typeof SQL_DIALECTS)[number];
export const DEFAULT_SQL_DIALECT: SqlDialectName = 'Postgres';

// OpenAPI dialects
export const OPENAPI_DIALECTS = ['OpenApi30', 'OpenApi31', 'Swagger20'] as const;
export type OpenApiDialectName = (typeof OPENAPI_DIALECTS)[number];
export const DEFAULT_OPENAPI_DIALECT: OpenApiDialectName = 'OpenApi30';

// MoonModel type names
export const MODEL_TYPES = [
  'Bool', 'Int', 'Big', 'Real', 'Text', 'Bytes', 'Stamp', 'Any',
] as const;
export type ModelTypeName = (typeof MODEL_TYPES)[number];

// Constraint names (for coverage matrix and drop reports)
export const CONSTRAINT_NAMES = [
  'least', 'most', 'over', 'under', 'step',
  'shortest', 'longest', 'pattern', 'format',
  'options', 'distinct', 'unique',
] as const;
export type ConstraintName = (typeof CONSTRAINT_NAMES)[number];

// Projection target keys
export const PROJECTION_KEYS = [
  'jsonSchema', 'openapi', 'sql', 'graphql',
  'typescript', 'zod', 'prisma',
] as const;
export type ProjectionKey = (typeof PROJECTION_KEYS)[number];

// Storage keys
export const STORAGE_KEYS = {
  STATE: 'projdesk_state',
  HISTORY: 'projdesk_history',
  THEME: 'projdesk_theme',
  ONBOARDED: 'projdesk_onboarded',
  LAST_BACKUP: 'projdesk_last_backup',
  TAB_STAMP: 'projdesk_tab_stamp',
} as const;

// Limits
export const LIMITS = {
  MAX_FIELD_NAME: 200,
  MAX_DOC: 5000,
  MAX_FIELDS: 500,
  MAX_MODELS: 50,
  MAX_PATTERN: 1000,
  MAX_OPTIONS: 100,
  MAX_HISTORY: 50,
  MAX_BACKUP_SIZE: 5_000_000,
  MAX_HASH_SIZE: 500_000,
} as const;

// Display names for dialects
export const DIALECT_LABELS: Record<string, string> = {
  OpenApi30: 'OpenAPI 3.0',
  OpenApi31: 'OpenAPI 3.1',
  Swagger20: 'Swagger 2.0',
  Postgres: 'Postgres',
  Sqlite: 'SQLite',
  Mysql: 'MySQL',
};
