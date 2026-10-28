// 前端类型定义：与 MoonBit 内核 ABI 一一对应
// 前端禁止实现任何 schema/sql/sdl 生成算法

/** 字段类型编码 */
export type TypeSpec =
  | 'Bool'
  | 'Int'
  | 'Big'
  | 'Real'
  | 'Text'
  | 'Bytes'
  | 'Stamp'
  | 'Any'
  | { list: TypeSpec }
  | { dict: TypeSpec }
  | { ref: string }
  | { nest: ModelInput }
  | { raw: unknown };

/** 约束 */
export interface CheckInput {
  least?: number | null;
  most?: number | null;
  over?: number | null;
  under?: number | null;
  step?: number | null;
  shortest?: number | null;
  longest?: number | null;
  pattern?: string | null;
  format?: string | null;
  options?: unknown[];
  distinct?: boolean;
  unique?: boolean;
}

/** 字段 */
export interface FieldInput {
  name: string;
  kind: TypeSpec;
  required: boolean;
  nullable: boolean;
  doc: string;
  default: unknown;
  check: CheckInput;
}

/** 模型 */
export interface ModelInput {
  name: string;
  doc: string;
  fields: FieldInput[];
}

/** 内核输入 */
export interface KernelInput {
  name: string;
  doc: string;
  fields: FieldInput[];
  known?: ModelInput[];
  openapiDialect?: 'OpenApi30' | 'OpenApi31' | 'Swagger20';
  sqlDialect?: 'Postgres' | 'Sqlite' | 'Mysql';
}

/** 丢弃原因 */
export interface DropReason {
  field: string;
  constraint: string;
  why: string;
}

/** 内核输出 */
export interface KernelOutput {
  ok: boolean;
  error?: string;
  jsonSchema: string;
  openapi: string;
  sql: string;
  graphql: string;
  typescript: string;
  zod: string;
  prisma: string;
  drops: {
    jsonSchema: DropReason[];
    openapi: DropReason[];
    sql: DropReason[];
    graphql: DropReason[];
    typescript: DropReason[];
    zod: DropReason[];
    prisma: DropReason[];
  };
}

/** 预设模型 */
export interface PresetModel extends ModelInput {}
