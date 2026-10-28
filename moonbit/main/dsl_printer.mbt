// AST Pretty-Printer: AST -> DSL source
// The inverse of parsing. Round-tripping through the printer proves the AST
// actually captures the source structure.

///|
/// Print a type back to DSL syntax
fn print_type(t : AstType) -> String {
  match t {
    Named(s) => s
    ListOf(inner) => "List(" + print_type(inner) + ")"
    DictOf(inner) => "Dict(" + print_type(inner) + ")"
    RefTo(name) => "Ref(" + name + ")"
    Nested(m) => "Nest { " + print_fields(m.fields) + " }"
  }
}

///|
/// Print fields separated by ", "
fn print_fields(fields : Array[AstField]) -> String {
  let parts = fields.map(print_field)
  parts.join(", ")
}

///|
/// Print a field back to DSL syntax
fn print_field(f : AstField) -> String {
  let out = StringBuilder()
  out.write_string(f.name)
  out.write_string(": ")
  out.write_string(print_type(f.kind))
  if !f.required {
    out.write_string(" @optional")
  }
  if f.nullable {
    out.write_string(" @nullable")
  }
  // @unique and @distinct are semantic flags carried in checks, printed as attributes
  let has_unique = f.checks.any(fn(ch) { ch == Unique })
  let has_distinct = f.checks.any(fn(ch) { ch == Distinct })
  if has_unique {
    out.write_string(" @unique")
  }
  if has_distinct {
    out.write_string(" @distinct")
  }
  for attr in f.attrs {
    out.write_string(" @")
    out.write_string(attr)
  }
  // Only bracket-style constraints go inside the brackets
  let checks = f.checks
    .filter(fn(ch) { ch != Unique && ch != Distinct })
    .map(print_check)
  if checks.length() > 0 {
    out.write_string(" [")
    out.write_string(checks.join(", "))
    out.write_string("]")
  }
  out.to_string()
}

///|
/// Print a check back to DSL syntax
fn print_check(c : AstCheck) -> String {
  match c {
    Least(b) => "least=" + b.expr.to_source()
    Most(b) => "most=" + b.expr.to_source()
    Over(b) => "over=" + b.expr.to_source()
    Under(b) => "under=" + b.expr.to_source()
    Step(b) => "step=" + b.expr.to_source()
    Shortest(b) => "shortest=" + b.expr.to_source()
    Longest(b) => "longest=" + b.expr.to_source()
    Pattern(s) => "pattern=\"" + s + "\""
    Format(s) => "format=" + s
    Options(vals) => "options=[" + vals.join(", ") + "]"
    Distinct => "distinct"
    Unique => "unique"
  }
}

///|
/// Print a model back to DSL source
pub fn print_model(m : AstModel) -> String {
  let out = StringBuilder()
  if m.doc != "" {
    out.write_string("// " + m.doc + "\n")
  }
  out.write_string("model " + m.name + " {\n")
  for f in m.fields {
    out.write_string("  ")
    out.write_string(print_field(f))
    out.write_string("\n")
  }
  out.write_string("}")
  out.to_string()
}

///|
/// Print several models back to DSL source
pub fn print_models(models : Array[AstModel]) -> String {
  let parts = models.map(print_model)
  parts.join("\n\n")
}
