// TypeScript / Zod / Prisma projections
// These are additional targets beyond moonmodel's four.
//
// Each emitter reports the constraints it cannot carry as typed drop reasons,
// the same contract the moonmodel-backed projectors use. Drop reporting
// covers the model being projected, matching the scope of the other targets.

///|
/// Escape a string for use inside a double-quoted JavaScript literal
fn js_string(s : String) -> String {
  let out = StringBuilder()
  out.write_string("\"")
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    match c {
      '\\' => out.write_string("\\\\")
      '"' => out.write_string("\\\"")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(c)
    }
  }
  out.write_string("\"")
  out.to_string()
}

///|
/// Render a JSON scalar as the text of a generated literal
fn json_literal(j : Json) -> String {
  match j {
    String(s) => js_string(s)
    Number(n, ..) => n.to_string()
    True => "true"
    False => "false"
    _ => "null"
  }
}

///|
/// Sanitize identifier: alphanumeric + underscore only, max 100 chars
fn safe_ident(name : String) -> String {
  let out = StringBuilder()
  let mut count = 0
  for i = 0; i < name.length() && count < 100; i = i + 1 {
    let code = name[i].to_int()
    if (code >= 97 && code <= 122) ||
      (code >= 65 && code <= 90) ||
      (code >= 48 && code <= 57) ||
      code == 95 {
      out.write_char(code.unsafe_to_char())
    } else {
      out.write_char('_')
    }
    count = count + 1
  }
  out.to_string()
}

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
    Nest(model) =>
      "{ " +
      model.fields.map(fn(f) { "\{f.name}: \{ts_type(f.kind)}" }).join("; ") +
      " }"
    Raw(_) => "unknown"
  }
}

///|
/// A TypeScript interface carries no runtime constraint, so every constraint
/// on a field is dropped and reported.
fn ts_drops(f : @moonmodel.Field) -> Array[DropReason] {
  let drops = []
  let c = f.check
  if c.unique {
    drops.push(UniqueNotCarried(f.name))
  }
  if c.distinct {
    drops.push(DistinctNotCarried(f.name))
  }
  if c.pattern is Some(_) {
    drops.push(PatternNotCarried(f.name))
  }
  if c.format is Some(_) {
    drops.push(FormatNotCarried(f.name))
  }
  if c.step is Some(_) {
    drops.push(StepNotCarried(f.name))
  }
  if c.shortest is Some(_) || c.longest is Some(_) {
    drops.push(LengthNotCarried(f.name))
  }
  if c.least is Some(_) {
    drops.push(BoundsNotCarried(f.name, "least"))
  }
  if c.most is Some(_) {
    drops.push(BoundsNotCarried(f.name, "most"))
  }
  if c.over is Some(_) {
    drops.push(BoundsNotCarried(f.name, "over"))
  }
  if c.under is Some(_) {
    drops.push(BoundsNotCarried(f.name, "under"))
  }
  if c.options.length() > 0 {
    drops.push(OptionsNotCarried(f.name))
  }
  drops
}

///|
/// TypeScript projector
pub(all) struct TsProjector {}

///|
pub impl Projector for TsProjector with fn target_name(_self) -> String {
  "TypeScript"
}

///|
pub extend TsProjector with Projector::{target_name, project}

///|
pub impl Projector for TsProjector with fn project(_self, model, known) -> (
  String,
  Array[DropReason],
) {
  let out = StringBuilder()
  // Emit referenced models first
  for k in known {
    out.write_string("export interface \{safe_ident(k.name)} {\n")
    for f in k.fields {
      let opt = if f.required { "" } else { "?" }
      out.write_string("  \{safe_ident(f.name)}\{opt}: \{ts_type(f.kind)};\n")
    }
    out.write_string("}\n\n")
  }
  out.write_string("export interface \{safe_ident(model.name)} {\n")
  for f in model.fields {
    let opt = if f.required { "" } else { "?" }
    out.write_string("  \{safe_ident(f.name)}\{opt}: \{ts_type(f.kind)};\n")
  }
  out.write_string("}\n")
  let drops = []
  for f in model.fields {
    for d in ts_drops(f) {
      drops.push(d)
    }
  }
  (out.to_string(), drops)
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
    Nest(model) =>
      "z.object({" +
      model.fields.map(fn(f) { "\{f.name}: \{zod_type(f.kind)}" }).join(", ") +
      "})"
    Raw(_) => "z.unknown()"
  }
}

///|
/// Whether numeric bounds apply to this type
fn zod_numeric(kind : @moonmodel.Type) -> Bool {
  match kind {
    Int | Big | Real => true
    _ => false
  }
}

///|
/// Whether length bounds and patterns apply to this type
fn zod_textual(kind : @moonmodel.Type) -> Bool {
  match kind {
    Text => true
    _ => false
  }
}

///|
/// Whether the field holds a list, so that item-level constraints apply
fn zod_list(kind : @moonmodel.Type) -> Bool {
  match kind {
    List(_) => true
    _ => false
  }
}

///|
/// The Zod method for a named string format, when Zod has one
fn zod_format_method(fmt : String) -> String? {
  match fmt {
    "email" => Some(".email()")
    "uri" => Some(".url()")
    "date-time" => Some(".datetime()")
    "uuid" => Some(".uuid()")
    "ipv4" => Some(".ip()")
    _ => None
  }
}

///|
/// Build the Zod constraint chain for one field, plus the constraints that
/// chain cannot carry
fn zod_constraints(f : @moonmodel.Field) -> (String, Array[DropReason]) {
  let chain = StringBuilder()
  let drops = []
  let c = f.check
  let numeric = zod_numeric(f.kind)
  let textual = zod_textual(f.kind)
  if c.options.length() > 0 {
    if textual {
      let items = c.options.map(fn(o) { json_literal(o) }).join(", ")
      chain.write_string(".enum([" + items + "])")
      // a closed set fixes the value, so no further string refinement applies
      if c.shortest is Some(_) || c.longest is Some(_) {
        drops.push(LengthNotCarried(f.name))
      }
      if c.pattern is Some(_) {
        drops.push(PatternNotCarried(f.name))
      }
      if c.format is Some(_) {
        drops.push(FormatNotCarried(f.name))
      }
    } else {
      drops.push(OptionsNotCarried(f.name))
    }
  } else {
    if textual {
      match c.shortest {
        Some(n) => chain.write_string(".min(" + n.to_string() + ")")
        None => ()
      }
      match c.longest {
        Some(n) => chain.write_string(".max(" + n.to_string() + ")")
        None => ()
      }
      match c.pattern {
        Some(p) =>
          chain.write_string(".regex(new RegExp(" + js_string(p) + "))")
        None => ()
      }
      match c.format {
        Some(fmt) =>
          match zod_format_method(fmt) {
            Some(m) => chain.write_string(m)
            None => drops.push(FormatNotCarried(f.name))
          }
        None => ()
      }
    } else {
      if c.shortest is Some(_) || c.longest is Some(_) {
        drops.push(LengthNotCarried(f.name))
      }
      if c.pattern is Some(_) {
        drops.push(PatternNotCarried(f.name))
      }
      if c.format is Some(_) {
        drops.push(FormatNotCarried(f.name))
      }
    }
    if numeric {
      match c.least {
        Some(n) => chain.write_string(".min(" + n.to_string() + ")")
        None => ()
      }
      match c.most {
        Some(n) => chain.write_string(".max(" + n.to_string() + ")")
        None => ()
      }
      match c.over {
        Some(n) => chain.write_string(".gt(" + n.to_string() + ")")
        None => ()
      }
      match c.under {
        Some(n) => chain.write_string(".lt(" + n.to_string() + ")")
        None => ()
      }
      match c.step {
        Some(n) => chain.write_string(".multipleOf(" + n.to_string() + ")")
        None => ()
      }
    } else {
      if c.least is Some(_) {
        drops.push(BoundsNotCarried(f.name, "least"))
      }
      if c.most is Some(_) {
        drops.push(BoundsNotCarried(f.name, "most"))
      }
      if c.over is Some(_) {
        drops.push(BoundsNotCarried(f.name, "over"))
      }
      if c.under is Some(_) {
        drops.push(BoundsNotCarried(f.name, "under"))
      }
      if c.step is Some(_) {
        drops.push(StepNotCarried(f.name))
      }
    }
  }
  if c.distinct {
    if zod_list(f.kind) {
      chain.write_string(
        ".refine((v) => new Set(v).size === v.length, { message: \"items must be distinct\" })",
      )
    } else {
      drops.push(DistinctNotCarried(f.name))
    }
  }
  if c.unique {
    // record-level uniqueness is a property of the collection, not the value
    drops.push(UniqueNotCarried(f.name))
  }
  (chain.to_string(), drops)
}

///|
/// Zod projector
pub(all) struct ZodProjector {}

///|
pub impl Projector for ZodProjector with fn target_name(_self) -> String {
  "Zod"
}

///|
pub extend ZodProjector with Projector::{target_name, project}

///|
pub impl Projector for ZodProjector with fn project(_self, model, known) -> (
  String,
  Array[DropReason],
) {
  let out = StringBuilder()
  out.write_string("import { z } from \"zod\";\n\n")
  for k in known {
    out.write_string("export const \{safe_ident(k.name)}Schema = z.object({\n")
    for f in k.fields {
      let base = zod_type(f.kind)
      let with_null = if f.nullable { "\{base}.nullable()" } else { base }
      let wrapped = if f.required {
        with_null
      } else {
        "\{with_null}.optional()"
      }
      out.write_string("  \{safe_ident(f.name)}: \{wrapped},\n")
    }
    out.write_string("});\n\n")
  }
  out.write_string(
    "export const \{safe_ident(model.name)}Schema = z.object({\n",
  )
  let drops = []
  for f in model.fields {
    let (chain, field_drops) = zod_constraints(f)
    for d in field_drops {
      drops.push(d)
    }
    let base = zod_type(f.kind)
    let constrained = base + chain
    let with_null = if f.nullable {
      "\{constrained}.nullable()"
    } else {
      constrained
    }
    let wrapped = if f.required { with_null } else { "\{with_null}.optional()" }
    out.write_string("  \{safe_ident(f.name)}: \{wrapped},\n")
  }
  out.write_string("});\n\n")
  out.write_string(
    "export type \{safe_ident(model.name)} = z.infer<typeof \{safe_ident(model.name)}Schema>;\n",
  )
  (out.to_string(), drops)
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
/// The constraints a Prisma schema cannot state portably
fn prisma_drops(f : @moonmodel.Field) -> Array[DropReason] {
  let drops = []
  let c = f.check
  if c.distinct {
    drops.push(DistinctNotCarried(f.name))
  }
  if c.pattern is Some(_) {
    drops.push(PatternNotCarried(f.name))
  }
  if c.format is Some(_) {
    drops.push(FormatNotCarried(f.name))
  }
  if c.step is Some(_) {
    drops.push(StepNotCarried(f.name))
  }
  if c.shortest is Some(_) || c.longest is Some(_) {
    drops.push(LengthNotCarried(f.name))
  }
  if c.least is Some(_) {
    drops.push(BoundsNotCarried(f.name, "least"))
  }
  if c.most is Some(_) {
    drops.push(BoundsNotCarried(f.name, "most"))
  }
  if c.over is Some(_) {
    drops.push(BoundsNotCarried(f.name, "over"))
  }
  if c.under is Some(_) {
    drops.push(BoundsNotCarried(f.name, "under"))
  }
  if c.options.length() > 0 {
    drops.push(OptionsNotCarried(f.name))
  }
  drops
}

///|
/// Prisma projector
pub(all) struct PrismaProjector {}

///|
pub impl Projector for PrismaProjector with fn target_name(_self) -> String {
  "Prisma"
}

///|
pub extend PrismaProjector with Projector::{target_name, project}

///|
pub impl Projector for PrismaProjector with fn project(_self, model, known) -> (
  String,
  Array[DropReason],
) {
  let out = StringBuilder()
  for k in known {
    out.write_string("model \{safe_ident(k.name)} {\n")
    for f in k.fields {
      let typ = prisma_type(f.kind)
      let opt = if f.required { "" } else { "?" }
      let attrs = if f.check.unique { " @unique" } else { "" }
      out.write_string("  \{safe_ident(f.name)} \{typ}\{opt}\{attrs}\n")
    }
    out.write_string("}\n\n")
  }
  out.write_string("model \{safe_ident(model.name)} {\n")
  for f in model.fields {
    let typ = prisma_type(f.kind)
    let opt = if f.required { "" } else { "?" }
    let attrs = if f.check.unique { " @unique" } else { "" }
    out.write_string("  \{safe_ident(f.name)} \{typ}\{opt}\{attrs}\n")
  }
  out.write_string("}\n")
  let drops = []
  for f in model.fields {
    for d in prisma_drops(f) {
      drops.push(d)
    }
  }
  (out.to_string(), drops)
}
