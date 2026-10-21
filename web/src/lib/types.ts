// 鍓嶇绫诲瀷瀹氫箟锛氫笌 MoonBit 鍐呮牳 ABI 涓€涓€瀵瑰簲
// 鍓嶇绂佹瀹炵幇浠讳綍 schema/sql/sdl 鐢熸垚绠楁硶

/** 瀛楁绫诲瀷缂栫爜 */
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

/** 绾︽潫 */
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

/** 瀛楁 */
export interface FieldInput {
  name: string;
  kind: TypeSpec;
  required: boolean;
  nullable: boolean;
  doc: string;
  default: unknown;
  check: CheckInput;
}

/** 妯″瀷 */
export interface ModelInput {
  name: string;
  doc: string;
  fields: FieldInput[];
}

/** 鍐呮牳杈撳叆 */
export interface KernelInput {
  name: string;
  doc: string;
  fields: FieldInput[];
  known?: ModelInput[];
  openapiDialect?: 'OpenApi30' | 'OpenApi31' | 'Swagger20';
  sqlDialect?: 'Postgres' | 'Sqlite' | 'Mysql';
}

/** 涓㈠純鍘熷洜 */
export interface DropReason {
  field: string;
  constraint: string;
  why: string;
}

/** 鍐呮牳杈撳嚭 */
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
  };
}

/** 棰勮妯″瀷 */
export interface PresetModel extends ModelInput {}


