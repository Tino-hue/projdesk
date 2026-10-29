// Round-trip verification: source -> AST -> source -> AST, compared field by
// field.
//
// The AST printer is the single place where DSL is emitted, so a round-trip
// exercises exactly the code a user would write by hand. The comparison
// covers every constraint, not just field names: a verifier that cannot see a
// lost constraint is worse than no verifier at all, because it reports a
// model as sound when it is not.

///|
/// Round-trip test result
pub(all) enum RoundTrip {
  Pass
  Fail(String)
} derive(Eq, Debug)

///|
pub extend RoundTrip with Eq::{equal, not_equal}

///|
pub extend RoundTrip with Debug::{to_repr}

///|
/// Whether a type carries a raw JSON payload, which the DSL cannot express
fn has_raw_type(t : @moonmodel.Type) -> Bool {
  match t {
    Raw(_) => true
    List(inner) => has_raw_type(inner)
    Dict(inner) => has_raw_type(inner)
    Nest(model) => model.fields.any(fn(f) { has_raw_type(f.kind) })
    _ => false
  }
}

///|
/// The first field whose type the DSL cannot express, or "" when there is none
fn find_raw_field(m : @moonmodel.Model) -> String {
  for f in m.fields {
    if has_raw_type(f.kind) {
      return f.name
    }
  }
  ""
}

///|
/// Why a model cannot be expressed in the DSL, or "" when it can
fn raw_type_error(m : @moonmodel.Model) -> String {
  let field = find_raw_field(m)
  if field == "" {
    return ""
  }
  "field " + field + " has a raw type, which the DSL cannot express"
}

///|
/// Convert a model type back into the AST the parser would have produced
fn model_type_to_ast(t : @moonmodel.Type) -> AstType {
  match t {
    Bool => Named("Bool")
    Int => Named("Int")
    Big => Named("Big")
    Real => Named("Real")
    Text => Named("Text")
    Bytes => Named("Bytes")
    Stamp => Named("Stamp")
    Any => Named("Any")
    List(inner) => ListOf(model_type_to_ast(inner))
    Dict(inner) => DictOf(model_type_to_ast(inner))
    Ref(name) => RefTo(name)
    Nest(model) => Nested(model_to_ast(model))
    // rejected earlier by raw_type_error
    Raw(_) => Named("Text")
  }
}

///|
/// Render an option value as DSL source text
fn option_text(j : Json) -> String {
  match j {
    String(s) => s
    Number(n, ..) => n.to_string()
    True => "true"
    False => "false"
    _ => "null"
  }
}

///|
/// Convert a model field back into the AST the parser would have produced
fn model_field_to_ast(f : @moonmodel.Field) -> AstField {
  let checks = []
  if f.check.unique {
    checks.push(Unique)
  }
  if f.check.distinct {
    checks.push(Distinct)
  }
  match f.check.least {
    Some(v) => checks.push(Least({ value: Some(v), expr: Num(v), }))
    None => ()
  }
  match f.check.most {
    Some(v) => checks.push(Most({ value: Some(v), expr: Num(v), }))
    None => ()
  }
  match f.check.over {
    Some(v) => checks.push(Over({ value: Some(v), expr: Num(v), }))
    None => ()
  }
  match f.check.under {
    Some(v) => checks.push(Under({ value: Some(v), expr: Num(v), }))
    None => ()
  }
  match f.check.step {
    Some(v) => checks.push(Step({ value: Some(v), expr: Num(v), }))
    None => ()
  }
  match f.check.shortest {
    Some(v) => {
      let d = v.to_double()
      checks.push(Shortest({ value: Some(d), expr: Num(d), }))
    }
    None => ()
  }
  match f.check.longest {
    Some(v) => {
      let d = v.to_double()
      checks.push(Longest({ value: Some(d), expr: Num(d), }))
    }
    None => ()
  }
  match f.check.pattern {
    Some(v) => checks.push(Pattern(v))
    None => ()
  }
  match f.check.format {
    Some(v) => checks.push(Format(v))
    None => ()
  }
  if f.check.options.length() > 0 {
    checks.push(Options(f.check.options.map(option_text)))
  }
  {
    name: f.name,
    kind: model_type_to_ast(f.kind),
    required: f.required,
    nullable: f.nullable,
    // the DSL grammar has no documentation construct
    doc: "",
    checks,
    attrs: [],
  }
}

///|
/// Convert a model back into the AST the parser would have produced
fn model_to_ast(m : @moonmodel.Model) -> AstModel {
  let fields = m.fields.map(model_field_to_ast)
  { name: m.name, fields, doc: "", }
}

///|
/// How two types differ, or "" when they are the same
fn type_difference(a : AstType, b : AstType) -> String {
  match (a, b) {
    (Named(x), Named(y)) => if x == y { "" } else { x + " -> " + y }
    (ListOf(x), ListOf(y)) => type_difference(x, y)
    (DictOf(x), DictOf(y)) => type_difference(x, y)
    (RefTo(x), RefTo(y)) =>
      if x == y {
        ""
      } else {
        "Ref(" + x + ") -> Ref(" + y + ")"
      }
    (Nested(x), Nested(y)) => ast_difference(x, y)
    _ => print_type(a) + " -> " + print_type(b)
  }
}

///|
/// How many times a key occurs in a list
fn count_key(keys : Array[String], key : String) -> Int32 {
  let mut n = 0
  for k in keys {
    if k == key {
      n = n + 1
    }
  }
  n
}

///|
/// How two constraint lists differ, or "" when they carry the same
/// constraints. Order is not significant: the printer emits record-level
/// flags as attributes, which moves them to the front of the list.
fn check_difference(a : Array[AstCheck], b : Array[AstCheck]) -> String {
  if a.length() != b.length() {
    return "constraint count changed: " +
      a.length().to_string() +
      " -> " +
      b.length().to_string()
  }
  let keys_a = a.map(fn(c) { print_check(c) })
  let keys_b = b.map(fn(c) { print_check(c) })
  for key in keys_a {
    let count_a = count_key(keys_a, key)
    let count_b = count_key(keys_b, key)
    if count_a != count_b {
      return "constraint " +
        key +
        " appears " +
        count_a.to_string() +
        " time(s), expected " +
        count_b.to_string()
    }
  }
  ""
}

///|
/// How two fields differ, or "" when they are the same
fn field_difference(a : AstField, b : AstField) -> String {
  if a.name != b.name {
    return "name changed: " + a.name + " -> " + b.name
  }
  if a.required != b.required {
    return "required changed: " +
      a.required.to_string() +
      " -> " +
      b.required.to_string()
  }
  if a.nullable != b.nullable {
    return "nullable changed: " +
      a.nullable.to_string() +
      " -> " +
      b.nullable.to_string()
  }
  let t = type_difference(a.kind, b.kind)
  if t != "" {
    return "type changed: " + t
  }
  let c = check_difference(a.checks, b.checks)
  if c != "" {
    return c
  }
  if a.attrs.length() != b.attrs.length() {
    return "attribute count changed: " +
      a.attrs.length().to_string() +
      " -> " +
      b.attrs.length().to_string()
  }
  for i = 0; i < a.attrs.length(); i = i + 1 {
    if a.attrs[i] != b.attrs[i] {
      return "attribute changed: " + a.attrs[i] + " -> " + b.attrs[i]
    }
  }
  ""
}

///|
/// How two parsed models differ, or "" when they are identical
pub fn ast_difference(a : AstModel, b : AstModel) -> String {
  if a.name != b.name {
    return "name changed: " + a.name + " -> " + b.name
  }
  if a.fields.length() != b.fields.length() {
    return "field count changed: " +
      a.fields.length().to_string() +
      " -> " +
      b.fields.length().to_string()
  }
  for i = 0; i < a.fields.length(); i = i + 1 {
    let d = field_difference(a.fields[i], b.fields[i])
    if d != "" {
      return "field " + a.fields[i].name + ": " + d
    }
  }
  ""
}

///|
/// Render a model as DSL source
pub fn model_to_dsl_public(m : @moonmodel.Model) -> String {
  print_model(model_to_ast(m))
}

///|
/// Print parsed models, parse the printed source again, and compare
fn ast_roundtrip(models : Array[AstModel]) -> RoundTrip {
  let printed = print_models(models)
  let (reparsed, lex_errors, parse_errors) = dsl_parse(printed)
  if lex_errors.length() > 0 {
    return Fail("lex errors in printed DSL: " + lex_errors[0].to_text())
  }
  if parse_errors.length() > 0 {
    return Fail("parse errors in printed DSL: " + parse_errors[0].to_text())
  }
  if reparsed.length() != models.length() {
    return Fail(
      "model count changed: " +
      models.length().to_string() +
      " -> " +
      reparsed.length().to_string(),
    )
  }
  for i = 0; i < models.length(); i = i + 1 {
    let d = ast_difference(models[i], reparsed[i])
    if d != "" {
      return Fail("model " + models[i].name + ": " + d)
    }
  }
  Pass
}

///|
/// Round-trip a model: model -> DSL -> parse -> AST, compared against the
/// model the DSL would have produced. The known models travel with it so that
/// references resolve.
pub fn roundtrip_model(
  m : @moonmodel.Model,
  known : Array[@moonmodel.Model],
) -> RoundTrip {
  let error = raw_type_error(m)
  if error != "" {
    return Fail(error)
  }
  let asts = [model_to_ast(m)]
  for k in known {
    let known_error = raw_type_error(k)
    if known_error != "" {
      return Fail(known_error)
    }
    asts.push(model_to_ast(k))
  }
  ast_roundtrip(asts)
}

///|
/// Round-trip DSL source: source -> AST -> source -> AST, compared
pub fn roundtrip_dsl(dsl : String) -> RoundTrip {
  let (models, lex_errors, parse_errors) = dsl_parse(dsl)
  if lex_errors.length() > 0 {
    return Fail("lex errors in input DSL: " + lex_errors[0].to_text())
  }
  if parse_errors.length() > 0 {
    return Fail("parse errors in input DSL: " + parse_errors[0].to_text())
  }
  if models.length() == 0 {
    return Fail("no models in input DSL")
  }
  ast_roundtrip(models)
}
