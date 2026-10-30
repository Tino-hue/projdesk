// Static satisfiability analysis of a JSON Schema.
//
// Every validator in the ecosystem answers one question: does this instance
// satisfy the schema? None of them answers the other one: can anything
// satisfy it? A schema that says `minimum: 10` and `maximum: 5` passes
// every conformance suite and rejects every value that reaches it.
//
// This module reads a JSON Schema — the format the ecosystem already speaks,
// and the one `moon_zod` and `moonschema` export — and reports the schemas
// that have no solution at all, before a single value is ever validated.
//
// It is the same interval algebra the constraint solver uses, pointed at the
// ecosystem's own artifact instead of at our own notation.

///|
/// One thing wrong with a schema
priv struct SchemaFinding {
  path : String
  kind : String
  message : String
} derive(ToJson)

///|
/// The report as it goes on the wire
priv struct SchemaCheckJson {
  ok : Bool
  findings : Array[SchemaFinding]
  finding_count : Double
} derive(ToJson)

///|
/// The numeric window that applies to one instance: a lower and an upper
/// bound, each of which may be open
priv struct Window {
  lo : Double?
  lo_open : Bool
  hi : Double?
  hi_open : Bool
}

///|
/// The length window that applies to one string instance
priv struct LengthWindow {
  shortest : Int32?
  longest : Int32?
}

///|
/// A window with no bounds at all
fn empty_window() -> Window {
  Window::{ lo: None, lo_open: false, hi: None, hi_open: false, }
}

///|
/// A length window with no bounds at all
fn empty_length() -> LengthWindow {
  LengthWindow::{ shortest: None, longest: None, }
}

///|
/// The tighter of two lower bounds; an exclusive bound is never weaker
fn tighter_lo(a : (Double?, Bool), b : (Double?, Bool)) -> (Double?, Bool) {
  match (a, b) {
    ((Some(x), x_open), (Some(y), y_open)) =>
      if x > y {
        (Some(x), x_open)
      } else if y > x {
        (Some(y), y_open)
      } else {
        (Some(x), x_open || y_open)
      }
    ((Some(x), x_open), (None, _)) => (Some(x), x_open)
    ((None, _), (Some(y), y_open)) => (Some(y), y_open)
    _ => (None, false)
  }
}

///|
/// The tighter of two upper bounds; an exclusive bound is never weaker
fn tighter_hi(a : (Double?, Bool), b : (Double?, Bool)) -> (Double?, Bool) {
  match (a, b) {
    ((Some(x), x_open), (Some(y), y_open)) =>
      if x < y {
        (Some(x), x_open)
      } else if y < x {
        (Some(y), y_open)
      } else {
        (Some(x), x_open || y_open)
      }
    ((Some(x), x_open), (None, _)) => (Some(x), x_open)
    ((None, _), (Some(y), y_open)) => (Some(y), y_open)
    _ => (None, false)
  }
}

///|
/// The number a keyword gives, and whether it excludes the bound itself
fn number_keyword(map : Map[String, Json], keyword : String) -> (Double?, Bool) {
  match map.get(keyword) {
    Some(Number(n, ..)) => (Some(n), false)
    _ => (None, false)
  }
}

///|
/// The number an exclusive keyword gives, excluding the bound itself
fn exclusive_number_keyword(
  map : Map[String, Json],
  keyword : String,
) -> (Double?, Bool) {
  match map.get(keyword) {
    Some(Number(n, ..)) => (Some(n), true)
    _ => (None, false)
  }
}

///|
/// The window a schema's own numeric keywords describe
fn window_of(schema : Json) -> Window {
  match schema {
    Object(map) => {
      let lo = tighter_lo(
        number_keyword(map, "minimum"),
        exclusive_number_keyword(map, "exclusiveMinimum"),
      )
      let hi = tighter_hi(
        number_keyword(map, "maximum"),
        exclusive_number_keyword(map, "exclusiveMaximum"),
      )
      Window::{ lo: lo.0, lo_open: lo.1, hi: hi.0, hi_open: hi.1, }
    }
    _ => empty_window()
  }
}

///|
/// The intersection of two windows: the tighter bound of each side wins
fn window_intersect(a : Window, b : Window) -> Window {
  let lo = tighter_lo((a.lo, a.lo_open), (b.lo, b.lo_open))
  let hi = tighter_hi((a.hi, a.hi_open), (b.hi, b.hi_open))
  Window::{ lo: lo.0, lo_open: lo.1, hi: hi.0, hi_open: hi.1, }
}

///|
/// Whether a window admits no value at all
fn window_empty(w : Window) -> Bool {
  match (w.lo, w.hi) {
    (Some(lo), Some(hi)) =>
      if lo > hi {
        true
      } else {
        lo == hi && (w.lo_open || w.hi_open)
      }
    _ => false
  }
}

///|
/// A human-readable description of a window
fn window_text(w : Window) -> String {
  let lo = match w.lo {
    Some(v) => (if w.lo_open { "(" } else { "[" }) + v.to_string()
    None => "(-inf"
  }
  let hi = match w.hi {
    Some(v) => v.to_string() + (if w.hi_open { ")" } else { "]" })
    None => "+inf)"
  }
  lo + ", " + hi
}

///|
/// The length window a schema's own keywords describe
fn length_of(schema : Json) -> LengthWindow {
  match schema {
    Object(map) => {
      let shortest = match map.get("minLength") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      let longest = match map.get("maxLength") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      LengthWindow::{ shortest, longest, }
    }
    _ => empty_length()
  }
}

///|
/// The intersection of two length windows
fn length_intersect(a : LengthWindow, b : LengthWindow) -> LengthWindow {
  let shortest = match (a.shortest, b.shortest) {
    (Some(x), Some(y)) => Some(if x > y { x } else { y })
    (Some(x), None) => Some(x)
    (None, Some(y)) => Some(y)
    (None, None) => None
  }
  let longest = match (a.longest, b.longest) {
    (Some(x), Some(y)) => Some(if x < y { x } else { y })
    (Some(x), None) => Some(x)
    (None, Some(y)) => Some(y)
    (None, None) => None
  }
  LengthWindow::{ shortest, longest, }
}

///|
/// Whether a length window admits no string at all
fn length_empty(l : LengthWindow) -> Bool {
  match (l.shortest, l.longest) {
    (Some(s), Some(m)) => s > m
    _ => false
  }
}

///|
/// The JSON types a schema allows, or None when it says nothing about types
fn types_of(schema : Json) -> Array[String]? {
  match schema {
    Object(map) =>
      match map.get("type") {
        Some(String(s)) => Some([s])
        Some(Array(items)) => {
          let out = []
          for item in items {
            match item {
              String(s) => out.push(s)
              _ => ()
            }
          }
          Some(out)
        }
        _ => None
      }
    _ => None
  }
}

///|
/// The values a schema's enum allows
fn enum_of(schema : Json) -> Array[Json]? {
  match schema {
    Object(map) =>
      match map.get("enum") {
        Some(Array(items)) => Some(items)
        _ => None
      }
    _ => None
  }
}

///|
/// The type name of a JSON value, in the vocabulary of the `type` keyword
fn value_type(v : Json) -> String {
  match v {
    String(_) => "string"
    Number(_, ..) => "number"
    True => "boolean"
    False => "boolean"
    Object(_) => "object"
    Array(_) => "array"
    Null => "null"
  }
}

///|
/// Whether a value satisfies a schema's own type, range and length keywords
fn value_fits(schema : Json, v : Json) -> Bool {
  match types_of(schema) {
    Some(types) => {
      let t = value_type(v)
      // an integer is also a number, as JSON Schema says
      let ok = types.contains(t) || (t == "number" && types.contains("integer"))
      if !ok {
        return false
      }
    }
    None => ()
  }
  match v {
    Number(n, ..) => {
      let w = window_of(schema)
      match w.lo {
        Some(lo) =>
          if w.lo_open {
            if n <= lo {
              return false
            }
          } else if n < lo {
            return false
          }
        None => ()
      }
      match w.hi {
        Some(hi) =>
          if w.hi_open {
            if n >= hi {
              return false
            }
          } else if n > hi {
            return false
          }
        None => ()
      }
      true
    }
    String(s) => {
      let l = length_of(schema)
      match l.shortest {
        Some(min) => if s.length() < min { return false }
        None => ()
      }
      match l.longest {
        Some(max) => if s.length() > max { return false }
        None => ()
      }
      true
    }
    _ => true
  }
}

///|
/// Whether the schema's own keywords already leave no value
fn local_empty(schema : Json) -> Bool {
  if window_empty(window_of(schema)) {
    return true
  }
  if length_empty(length_of(schema)) {
    return true
  }
  match enum_of(schema) {
    Some(values) =>
      if values.length() > 0 {
        let mut fits = false
        for v in values {
          if value_fits(schema, v) {
            fits = true
            break
          }
        }
        if !fits {
          return true
        }
      }
    None => ()
  }
  false
}

///|
/// Undo the JSON Pointer escaping of one segment
fn decode_pointer(segment : String) -> String {
  let mut out = ""
  let mut i = 0
  while i < segment.length() {
    let c = segment[i]
    if c == '~' && i + 1 < segment.length() {
      let n = segment[i + 1]
      if n == '1' {
        out = out + "/"
        i = i + 2
        continue
      }
      if n == '0' {
        out = out + "~"
        i = i + 2
        continue
      }
    }
    out = out + c.to_string()
    i = i + 1
  }
  out
}

///|
/// Follow a `$ref` to the schema it points at, if it is an internal one
fn resolve_ref(root : Json, ref_str : String) -> Json? {
  if !ref_str.has_prefix("#/") {
    return None
  }
  let path = ref_str[2:].to_owned()
  let mut current = root
  for segment in path.split("/") {
    let key = decode_pointer(segment.to_owned())
    current = match current {
      Object(map) =>
        match map.get(key) {
          Some(next) => next
          None => return None
        }
      _ => return None
    }
  }
  Some(current)
}

///|
/// The schema a subschema really means: itself, or what its `$ref` points at
fn deref(root : Json, schema : Json) -> Json {
  match schema {
    Object(map) =>
      match map.get("$ref") {
        Some(String(r)) =>
          match resolve_ref(root, r) {
            Some(target) => target
            None => schema
          }
        _ => schema
      }
    _ => schema
  }
}

///|
/// The branches a schema offers under a keyword
fn branches_of(map : Map[String, Json], keyword : String) -> Array[Json]? {
  match map.get(keyword) {
    Some(Array(items)) => Some(items)
    _ => None
  }
}

///|
/// Whether any value at all can satisfy this subschema
fn satisfiable(root : Json, schema : Json, seen : Array[String]) -> Bool {
  match schema {
    Object(map) =>
      match map.get("$ref") {
        Some(String(r)) => {
          if seen.contains(r) {
            return true
          }
          match resolve_ref(root, r) {
            Some(target) => satisfiable(root, target, seen + [r])
            // a dangling reference cannot be judged, so it is not called a
            // contradiction — it is called out as a finding of its own
            None => true
          }
        }
        _ => {
          if local_empty(schema) {
            return false
          }
          let own = window_of(schema)
          let own_len = length_of(schema)
          // allOf: every branch applies to the same instance
          match branches_of(map, "allOf") {
            Some(branches) => {
              let mut merged = own
              let mut merged_len = own_len
              for b in branches {
                let target = deref(root, b)
                if !satisfiable(root, target, seen) {
                  return false
                }
                merged = window_intersect(merged, window_of(target))
                merged_len = length_intersect(merged_len, length_of(target))
              }
              if window_empty(merged) || length_empty(merged_len) {
                return false
              }
            }
            None => ()
          }
          // anyOf and oneOf: at least one branch has to work
          for keyword in ["anyOf", "oneOf"] {
            match branches_of(map, keyword) {
              Some(branches) => {
                let mut any = false
                for b in branches {
                  if satisfiable(root, deref(root, b), seen) {
                    any = true
                    break
                  }
                }
                if !any {
                  return false
                }
              }
              None => ()
            }
          }
          // not: the negated schema has to be satisfiable for this to be
          match map.get("not") {
            Some(inner) =>
              if !satisfiable(root, deref(root, inner), seen) {
                return false
              }
            None => ()
          }
          true
        }
      }
    _ => true
  }
}

///|
/// Add every finding of one call to the accumulator
fn push_all(out : Array[SchemaFinding], more : Array[SchemaFinding]) -> Unit {
  for f in more {
    out.push(f)
  }
}

///|
/// Collect everything wrong with a schema
fn collect(
  root : Json,
  schema : Json,
  path : String,
  findings : Array[SchemaFinding],
  seen : Array[String],
) -> Array[SchemaFinding] {
  match schema {
    Object(map) => {
      let out = findings
      // a dangling reference
      match map.get("$ref") {
        Some(String(r)) =>
          if !seen.contains(r) {
            match resolve_ref(root, r) {
              Some(target) =>
                push_all(out, collect(root, target, path, [], seen + [r]))
              None =>
                out.push(SchemaFinding::{
                  path,
                  kind: "dangling_ref",
                  message: "the reference " +
                  r +
                  " points at nothing in this document",
                })
            }
          }
        _ => ()
      }
      // the schema's own bounds
      let own = window_of(schema)
      if window_empty(own) {
        out.push(SchemaFinding::{
          path,
          kind: "empty_range",
          message: "no number satisfies these bounds: " + window_text(own),
        })
      }
      let own_len = length_of(schema)
      if length_empty(own_len) {
        out.push(SchemaFinding::{
          path,
          kind: "empty_length",
          message: "no string satisfies these length bounds",
        })
      }
      // an enum that no value of it can satisfy
      match enum_of(schema) {
        Some(values) =>
          if values.length() > 0 {
            let mut fits = false
            for v in values {
              if value_fits(schema, v) {
                fits = true
                break
              }
            }
            if !fits {
              out.push(SchemaFinding::{
                path,
                kind: "empty_enum",
                message: "none of the enumerated values satisfies this schema",
              })
            }
          }
        None => ()
      }
      // multipleOf has to be positive
      match map.get("multipleOf") {
        Some(Number(n, ..)) =>
          if n <= 0.0 {
            out.push(SchemaFinding::{
              path,
              kind: "invalid_multiple_of",
              message: "multipleOf must be greater than zero",
            })
          }
        _ => ()
      }
      // allOf: the branches apply to the same instance, so their bounds meet
      match branches_of(map, "allOf") {
        Some(branches) => {
          let mut merged = own
          let mut merged_len = own_len
          for b in branches {
            let target = deref(root, b)
            merged = window_intersect(merged, window_of(target))
            merged_len = length_intersect(merged_len, length_of(target))
          }
          if window_empty(merged) && !window_empty(own) {
            out.push(SchemaFinding::{
              path,
              kind: "empty_range",
              message: "the allOf branches together leave no number: " +
              window_text(merged),
            })
          }
          if length_empty(merged_len) && !length_empty(own_len) {
            out.push(SchemaFinding::{
              path,
              kind: "empty_length",
              message: "the allOf branches together leave no string",
            })
          }
          for i = 0; i < branches.length(); i = i + 1 {
            push_all(
              out,
              collect(
                root,
                branches[i],
                path + "/allOf/" + i.to_string(),
                [],
                seen,
              ),
            )
          }
        }
        None => ()
      }
      // anyOf and oneOf: a branch that cannot work at all
      for keyword in ["anyOf", "oneOf"] {
        match branches_of(map, keyword) {
          Some(branches) => {
            let mut live = 0
            for b in branches {
              if satisfiable(root, deref(root, b), seen) {
                live = live + 1
              }
            }
            if live == 0 {
              out.push(SchemaFinding::{
                path,
                kind: "no_live_branch",
                message: "every " + keyword + " branch is impossible",
              })
            }
            for i = 0; i < branches.length(); i = i + 1 {
              push_all(
                out,
                collect(
                  root,
                  branches[i],
                  path + "/" + keyword + "/" + i.to_string(),
                  [],
                  seen,
                ),
              )
            }
          }
          None => ()
        }
      }
      // not: a schema that excludes everything
      match map.get("not") {
        Some(inner) => {
          let target = deref(root, inner)
          if !satisfiable(root, target, seen) {
            out.push(SchemaFinding::{
              path,
              kind: "empty_not",
              message: "this schema excludes every value, because what it " +
              "negates is itself impossible",
            })
          }
          push_all(out, collect(root, target, path + "/not", [], seen))
        }
        None => ()
      }
      // if / then / else
      match map.get("if") {
        Some(inner) =>
          push_all(
            out,
            collect(root, deref(root, inner), path + "/if", [], seen),
          )
        None => ()
      }
      for keyword in ["then", "else"] {
        match map.get(keyword) {
          Some(inner) => {
            let target = deref(root, inner)
            if !satisfiable(root, target, seen) {
              out.push(SchemaFinding::{
                path,
                kind: "dead_branch",
                message: "the " +
                keyword +
                " branch can never be reached, because it is impossible " +
                "on its own",
              })
            }
            push_all(out, collect(root, target, path + "/" + keyword, [], seen))
          }
          None => ()
        }
      }
      // properties
      match map.get("properties") {
        Some(Object(props)) =>
          for (name, sub) in props.iter() {
            push_all(
              out,
              collect(root, sub, path + "/properties/" + name, [], seen),
            )
          }
        _ => ()
      }
      // items and additionalProperties
      match map.get("items") {
        Some(sub) =>
          push_all(out, collect(root, sub, path + "/items", [], seen))
        None => ()
      }
      match map.get("additionalProperties") {
        Some(sub) =>
          push_all(
            out,
            collect(root, sub, path + "/additionalProperties", [], seen),
          )
        _ => ()
      }
      // definitions
      for keyword in ["$defs", "definitions"] {
        match map.get(keyword) {
          Some(Object(defs)) =>
            for (name, sub) in defs.iter() {
              push_all(
                out,
                collect(root, sub, path + "/" + keyword + "/" + name, [], seen),
              )
            }
          _ => ()
        }
      }
      out
    }
    _ => findings
  }
}

///|
/// Check a JSON Schema for contradictions, and report them as JSON
pub fn check_json_schema(schema : Json) -> String {
  let findings = collect(schema, schema, "", [], [])
  ToJson::to_json(SchemaCheckJson::{
    ok: findings.length() == 0,
    findings,
    finding_count: findings.length().to_double(),
  }).stringify()
}

///|
/// Check a JSON Schema given as text
pub fn check_json_schema_str(text : String) -> String {
  check_json_schema(@jsonparse.parse_json(text))
}
