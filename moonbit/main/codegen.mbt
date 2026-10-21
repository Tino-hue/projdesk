// TypeScript / Zod / Prisma projections
// These are additional targets beyond moonmodel's four

///|
/// TypeScript type from moonmodel.Type
fn ts_type(kind : @moonmodel.Type) -> String {
  match kind {
    Bool => "boolean"
    Int | Big => "number"
    Real => "number"
    Text => "string"
    Bytes => "Uint8Array"
    Stamp => "Date"
    Any => "unknown"
    List(inner) => "\{ts_type(inner)}[]"
    Dict(inner) => "Record<string, \{ts_type(inner)}>"
    Ref(name) => name
    Nest(model) => "{ " + model.fields.map(fn(f) { "\{f.name}: \{ts_type(f.kind)}" }).join("; ") + " }"
    Raw(_) => "unknown"
  }
}

///|
/// TypeScript interface projection
pub fn project_typescript(
  model : @moonmodel.Model,
  known : Array[@moonmodel.Model],
) -> String {
  let out = StringBuilder()
  // Emit referenced models first
  for k in known {
    out.write_string("export interface \{k.name} {\n")
    for f in k.fields {
      let opt = if f.required { "" } else { "?" }
      out.write_string("  \{f.name}\{opt}: \{ts_type(f.kind)};\n")
    }
    out.write_string("}\n\n")
  }
  out.write_string("export interface \{model.name} {\n")
  for f in model.fields {
    let opt = if f.required { "" } else { "?" }
    out.write_string("  \{f.name}\{opt}: \{ts_type(f.kind)};\n")
  }
  out.write_string("}\n")
  out.to_string()
}

///|
/// Zod schema type from moonmodel.Type
fn zod_type(kind : @moonmodel.Type) -> String {
  match kind {
    Bool => "z.boolean()"
    Int => "z.number().int()"
    Big => "z.number().int()"
    Real => "z.number()"
    Text => "z.string()"
    Bytes => "z.instanceof(Uint8Array)"
    Stamp => "z.date()"
    Any => "z.unknown()"
    List(inner) => "z.array(\{zod_type(inner)})"
    Dict(inner) => "z.record(z.string(), \{zod_type(inner)})"
    Ref(name) => name
    Nest(model) => "z.object({" + model.fields.map(fn(f) { "\{f.name}: \{zod_type(f.kind)}" }).join(", ") + "})"
    Raw(_) => "z.unknown()"
  }
}

///|
/// Zod schema projection
pub fn project_zod(
  model : @moonmodel.Model,
  known : Array[@moonmodel.Model],
) -> String {
  let out = StringBuilder()
  out.write_string("import { z } from \"zod\";\n\n")
  for k in known {
    out.write_string("export const \{k.name}Schema = z.object({\n")
    for f in k.fields {
      let base = zod_type(f.kind)
      let with_null = if f.nullable { "\{base}.nullable()" } else { base }
      let wrapped = if f.required { with_null } else { "\{with_null}.optional()" }
      out.write_string("  \{f.name}: \{wrapped},\n")
    }
    out.write_string("});\n\n")
  }
  out.write_string("export const \{model.name}Schema = z.object({\n")
  for f in model.fields {
    let base = zod_type(f.kind)
    let with_null = if f.nullable { "\{base}.nullable()" } else { base }
    let wrapped = if f.required { with_null } else { "\{with_null}.optional()" }
    out.write_string("  \{f.name}: \{wrapped},\n")
  }
  out.write_string("});\n\n")
  out.write_string("export type \{model.name} = z.infer<typeof \{model.name}Schema>;\n")
  out.to_string()
}

///|
/// Prisma type from moonmodel.Type
fn prisma_type(kind : @moonmodel.Type) -> String {
  match kind {
    Bool => "Boolean"
    Int => "Int"
    Big => "BigInt"
    Real => "Float"
    Text => "String"
    Bytes => "Bytes"
    Stamp => "DateTime"
    Any => "Json"
    List(inner) => "\{prisma_type(inner)}[]"
    Dict(_) => "Json"
    Ref(name) => name
    Nest(_) => "Json"
    Raw(_) => "Json"
  }
}

///|
/// Prisma model projection
pub fn project_prisma(
  model : @moonmodel.Model,
  known : Array[@moonmodel.Model],
) -> String {
  let out = StringBuilder()
  for k in known {
    out.write_string("model \{k.name} {\n")
    for f in k.fields {
      let typ = prisma_type(f.kind)
      let opt = if f.required { "" } else { "?" }
      let attrs = if f.check.unique { " @unique" } else { "" }
      out.write_string("  \{f.name} \{typ}\{opt}\{attrs}\n")
    }
    out.write_string("}\n\n")
  }
  out.write_string("model \{model.name} {\n")
  for f in model.fields {
    let typ = prisma_type(f.kind)
    let opt = if f.required { "" } else { "?" }
    let attrs = if f.check.unique { " @unique" } else { "" }
    out.write_string("  \{f.name} \{typ}\{opt}\{attrs}\n")
  }
  out.write_string("}\n")
  out.to_string()
}
