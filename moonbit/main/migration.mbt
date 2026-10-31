// Model Migration Engine: structured diff + migration code generation
// Pure MoonBit algorithmic engine

///|
/// A single change between two model versions
pub(all) enum Migration {
  FieldAdded(String, String) // name, type_desc
  FieldRemoved(String)
  TypeChanged(String, String, String) // name, old_type, new_type
  ConstraintAdded(String, String) // field, constraint_desc
  ConstraintRemoved(String, String) // field, constraint_desc
  /// A constraint changed value; `narrowing` says whether the field now
  /// accepts fewer values
  ConstraintChanged(String, String, String, String, Bool) // field, kind, old, new, narrowing
  /// A constraint change that does not change what the field accepts
  RedundantConstraint(String, String) // field, constraint_desc
  /// The change leaves the field with no satisfying value at all
  Unsatisfiable(String, String) // field, why
  RequiredChanged(String, Bool, Bool) // name, old, new
  NullableChanged(String, Bool, Bool) // name, old, new
  Renamed(String, String) // old_name, new_name
} derive(Eq, Debug)

///|
pub extend Migration with Eq::{equal, not_equal}

///|
pub extend Migration with Debug::{to_repr}

///|
pub extend MigrationReport with Eq::{equal, not_equal}

///|
pub extend MigrationReport with Debug::{to_repr}

///|

///|
pub fn Migration::to_text(self : Migration) -> String {
  match self {
    FieldAdded(n, t) => "+ field \{n} : \{t}"
    FieldRemoved(n) => "- field \{n}"
    TypeChanged(n, old, new) => "~ type \{n} : \{old} -> \{new}"
    ConstraintAdded(f, c) => "+ check \{f}.\{c}"
    ConstraintRemoved(f, c) => "- check \{f}.\{c}"
    ConstraintChanged(f, kind, old, new, _) =>
      "~ check \{f}.\{kind}: \{old} -> \{new}"
    RedundantConstraint(f, c) =>
      "~ check \{f}.\{c} changes nothing: another constraint already implies it"
    Unsatisfiable(f, why) => "[CONFLICT] \{f}: \{why}"
    RequiredChanged(n, old, new) => "~ required \{n} : \{old} -> \{new}"
    NullableChanged(n, old, new) => "~ nullable \{n} : \{old} -> \{new}"
    Renamed(old, new) => "rename \{old} -> \{new}"
  }
}

///|
/// Is this a breaking change?
pub fn Migration::is_breaking(self : Migration) -> Bool {
  match self {
    FieldRemoved(_) => true
    TypeChanged(_, _, _) => true
    RequiredChanged(_, false, true) => true // making optional -> required
    NullableChanged(_, true, false) => true // making nullable -> non-null
    ConstraintAdded(_, _) => true // adding constraints can reject existing data
    // a constraint that changed to a value accepting more of them rejects
    // nothing that exists
    ConstraintChanged(_, _, _, _, narrowing) => narrowing
    Unsatisfiable(_, _) => true // the field now accepts nothing at all
    // a constraint another constraint already implies accepts the same values
    // before and after, so nothing that exists can be rejected by it
    RedundantConstraint(_, _) => false
    _ => false
  }
}

///|
/// Full migration report
pub(all) struct MigrationReport {
  changes : Array[Migration]
  breaking_count : Int32
} derive(Eq, Debug)

///|

///|
/// Type description string
fn type_desc(t : @moonmodel.Type) -> String {
  match t {
    Bool => "Bool"
    Int => "Int"
    Big => "Big"
    Real => "Real"
    Text => "Text"
    Bytes => "Bytes"
    Stamp => "Stamp"
    Any => "Any"
    List(inner) => "List(" + type_desc(inner) + ")"
    Dict(inner) => "Dict(" + type_desc(inner) + ")"
    Ref(name) => "Ref(" + name + ")"
    Nest(_) => "Nest(...)"
    Raw(_) => "Raw(...)"
  }
}

///|
/// One constraint of a field, with the name of what it constrains
///
/// A diff that compares constraint *text* cannot tell a change that accepts
/// fewer values from one that accepts more, and it reports a value that was
/// merely replaced as one removal and one addition.
priv struct ConstraintPart {
  /// what the constraint constrains: "least", "longest", "options", ...
  kind : String
  /// the constraint as it is written in a diff line
  text : String
  /// the numeric value, when the constraint has one
  number : Double?
  /// a lower bound tightens when it grows, an upper bound when it shrinks
  is_lower : Bool
}

///|
/// The constraints of a field, one entry per constraint
fn check_parts(c : @moonmodel.Check) -> Array[ConstraintPart] {
  let parts = []
  match c.least {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "least",
        text: "least=\{v}",
        number: Some(v),
        is_lower: true,
      })
    None => ()
  }
  match c.most {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "most",
        text: "most=\{v}",
        number: Some(v),
        is_lower: false,
      })
    None => ()
  }
  match c.over {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "over",
        text: "over=\{v}",
        number: Some(v),
        is_lower: true,
      })
    None => ()
  }
  match c.under {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "under",
        text: "under=\{v}",
        number: Some(v),
        is_lower: false,
      })
    None => ()
  }
  match c.step {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "step",
        text: "step=\{v}",
        number: Some(v),
        is_lower: false,
      })
    None => ()
  }
  match c.shortest {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "shortest",
        text: "shortest=\{v}",
        number: Some(v.to_double()),
        is_lower: true,
      })
    None => ()
  }
  match c.longest {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "longest",
        text: "longest=\{v}",
        number: Some(v.to_double()),
        is_lower: false,
      })
    None => ()
  }
  match c.pattern {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "pattern",
        text: "pattern=\{v}",
        number: None,
        is_lower: false,
      })
    None => ()
  }
  match c.format {
    Some(v) =>
      parts.push(ConstraintPart::{
        kind: "format",
        text: "format=\{v}",
        number: None,
        is_lower: false,
      })
    None => ()
  }
  if c.options.length() > 0 {
    let values = []
    for o in c.options {
      values.push(option_text(o))
    }
    let mut joined = ""
    for i = 0; i < values.length(); i = i + 1 {
      if i > 0 {
        joined = joined + ","
      }
      joined = joined + values[i]
    }
    parts.push(ConstraintPart::{
      kind: "options",
      text: "options[\{joined}]",
      number: None,
      is_lower: false,
    })
  }
  if c.distinct {
    parts.push(ConstraintPart::{
      kind: "distinct",
      text: "distinct",
      number: None,
      is_lower: false,
    })
  }
  if c.unique {
    parts.push(ConstraintPart::{
      kind: "unique",
      text: "unique",
      number: None,
      is_lower: false,
    })
  }
  parts
}

///|
/// The constraint of a field with the given name, if it has one
fn find_part(parts : Array[ConstraintPart], kind : String) -> ConstraintPart? {
  for p in parts {
    if p.kind == kind {
      return Some(p)
    }
  }
  None
}

///|
/// Does this change make the field accept fewer values?
///
/// A lower bound that grows tightens the field, an upper bound that shrinks
/// tightens it. A constraint that is not a bound is judged the safe way: any
/// change to it may reject what exists.
fn part_narrows(old_part : ConstraintPart, new_part : ConstraintPart) -> Bool {
  match (old_part.number, new_part.number) {
    (Some(o), Some(n)) => if old_part.is_lower { n > o } else { n < o }
    _ => true
  }
}

///|
/// Diff two models and produce migration steps
pub fn diff_models(
  old_model : @moonmodel.Model,
  new_model : @moonmodel.Model,
) -> MigrationReport {
  let changes : Array[Migration] = []
  let old_fields = old_model.fields
  let new_fields = new_model.fields

  // Index fields by name
  let old_names = old_fields.map(fn(f) { f.name })
  let new_names = new_fields.map(fn(f) { f.name })

  // Find removed fields
  for f in old_fields {
    if !new_names.contains(f.name) {
      changes.push(FieldRemoved(f.name))
    }
  }

  // Find added fields
  for f in new_fields {
    if !old_names.contains(f.name) {
      changes.push(FieldAdded(f.name, type_desc(f.kind)))
    }
  }

  // Find modified fields
  for old_f in old_fields {
    match new_model.field(old_f.name) {
      Some(new_f) => {
        // Type change
        if type_desc(old_f.kind) != type_desc(new_f.kind) {
          changes.push(
            TypeChanged(
              old_f.name,
              type_desc(old_f.kind),
              type_desc(new_f.kind),
            ),
          )
        }
        // Required change
        if old_f.required != new_f.required {
          changes.push(
            RequiredChanged(old_f.name, old_f.required, new_f.required),
          )
        }
        // Nullable change
        if old_f.nullable != new_f.nullable {
          changes.push(
            NullableChanged(old_f.name, old_f.nullable, new_f.nullable),
          )
        }
        // Constraint changes, judged by what they allow rather than by their
        // text: a constraint another one already implies changes nothing, a
        // change that leaves the field with no satisfying value is not merely
        // a constraint swap, and a value that was replaced is one change
        // rather than a removal plus an addition.
        let old_parts = check_parts(old_f.check)
        let new_parts = check_parts(new_f.check)
        let old_subsumed = subsumed_constraints(old_f.check).map(fn(s) {
          s.part
        })
        let new_subsumed = subsumed_constraints(new_f.check).map(fn(s) {
          s.part
        })
        let old_conflicts = field_conflicts(old_f.check)
        let new_conflicts = field_conflicts(new_f.check)
        let pending = []
        let mut touched = false
        for np in new_parts {
          match find_part(old_parts, np.kind) {
            Some(op) =>
              if op.text != np.text {
                touched = true
                if old_subsumed.contains(op.text) &&
                  new_subsumed.contains(np.text) {
                  pending.push(RedundantConstraint(old_f.name, op.text))
                } else {
                  pending.push(
                    ConstraintChanged(
                      old_f.name,
                      np.kind,
                      op.text,
                      np.text,
                      part_narrows(op, np),
                    ),
                  )
                }
              }
            None => {
              touched = true
              if new_subsumed.contains(np.text) {
                pending.push(RedundantConstraint(old_f.name, np.text))
              } else {
                pending.push(ConstraintAdded(old_f.name, np.text))
              }
            }
          }
        }
        for op in old_parts {
          if find_part(new_parts, op.kind) is None {
            touched = true
            if old_subsumed.contains(op.text) {
              pending.push(RedundantConstraint(old_f.name, op.text))
            } else {
              pending.push(ConstraintRemoved(old_f.name, op.text))
            }
          }
        }
        if touched && new_conflicts.length() > old_conflicts.length() {
          // the change left the field with no satisfying value at all, which
          // says more than the constraint swap it came from
          changes.push(Unsatisfiable(old_f.name, new_conflicts[0]))
        } else {
          for c in pending {
            changes.push(c)
          }
        }
      }
      None => ()
    }
  }

  // Count breaking changes
  let mut breaking = 0
  for c in changes {
    if c.is_breaking() {
      breaking = breaking + 1
    }
  }

  { changes, breaking_count: breaking, }
}

///|
/// Generate SQL ALTER TABLE migration
pub fn generate_sql_migration(
  old_model : @moonmodel.Model,
  new_model : @moonmodel.Model,
  dialect~ : String = "Postgres",
) -> String {
  let report = diff_models(old_model, new_model)
  let out = StringBuilder()
  out.write_string("-- Migration: \{old_model.name} -> \{new_model.name}\n")
  if report.breaking_count > 0 {
    out.write_string(
      "-- WARNING: \{report.breaking_count} breaking change(s)!\n",
    )
  }
  out.write_string("-- Dialect: \{dialect}\n\n")

  let table_name = new_model.name
  for change in report.changes {
    match change {
      FieldAdded(name, _) =>
        match new_model.field(name) {
          Some(f) => {
            let type_str = match dialect {
              "Sqlite" =>
                match f.kind {
                  Bool => "INTEGER"
                  Int | Big => "INTEGER"
                  Real => "REAL"
                  Text => "TEXT"
                  Bytes => "BLOB"
                  Stamp => "TEXT"
                  _ => "TEXT"
                }
              "Mysql" =>
                match f.kind {
                  Bool => "TINYINT(1)"
                  Int => "INT"
                  Big => "BIGINT"
                  Real => "DOUBLE"
                  Text => "TEXT"
                  Bytes => "BLOB"
                  Stamp => "DATETIME"
                  _ => "TEXT"
                }
              _ =>
                match f.kind {
                  Bool => "BOOLEAN"
                  Int => "INTEGER"
                  Big => "BIGINT"
                  Real => "DOUBLE PRECISION"
                  Text => "TEXT"
                  Bytes => "BYTEA"
                  Stamp => "TIMESTAMPTZ"
                  _ => "TEXT"
                }
            }
            let not_null = if f.required && !f.nullable {
              " NOT NULL"
            } else {
              ""
            }
            out.write_string(
              "ALTER TABLE \{table_name} ADD COLUMN \{name} \{type_str}\{not_null};\n",
            )
          }
          None => ()
        }
      FieldRemoved(name) =>
        out.write_string("ALTER TABLE \{table_name} DROP COLUMN \{name};\n")
      TypeChanged(name, _old, _new) =>
        out.write_string(
          "-- TODO: ALTER TABLE \{table_name} ALTER COLUMN \{name} TYPE ... (manual)\n",
        )
      ConstraintAdded(field, c) =>
        if c == "unique" {
          out.write_string(
            "ALTER TABLE \{table_name} ADD CONSTRAINT \{table_name}_\{field}_unique UNIQUE (\{field});\n",
          )
        }
      ConstraintRemoved(field, c) =>
        if c == "unique" {
          out.write_string(
            "ALTER TABLE \{table_name} DROP CONSTRAINT \{table_name}_\{field}_unique;\n",
          )
        }
      ConstraintChanged(field, kind, _old, _new, narrowing) =>
        out.write_string(
          "-- note: \{field}.\{kind} changed\{if narrowing { ", accepts fewer values" } else { ", accepts more values" }}\n",
        )
      RedundantConstraint(field, c) =>
        out.write_string(
          "-- note: \{field}.\{c} changes nothing, another constraint already implies it\n",
        )
      Unsatisfiable(field, why) =>
        out.write_string(
          "-- ERROR: \{field} now accepts no value at all (\{why})\n",
        )
      RequiredChanged(name, false, true) =>
        out.write_string(
          "ALTER TABLE \{table_name} ALTER COLUMN \{name} SET NOT NULL;\n",
        )
      RequiredChanged(name, true, false) =>
        out.write_string(
          "ALTER TABLE \{table_name} ALTER COLUMN \{name} DROP NOT NULL;\n",
        )
      RequiredChanged(_, _, _) => ()
      NullableChanged(_, _, _) =>
        // Handled by RequiredChanged in SQL context
        ()
      Renamed(old_n, new_n) =>
        out.write_string(
          "ALTER TABLE \{table_name} RENAME COLUMN \{old_n} TO \{new_n};\n",
        )
    }
  }
  out.to_string()
}

///|
/// One change as it goes on the wire
priv struct WireMigrationChange {
  text : String
  breaking : Bool
} derive(ToJson)

///|
/// The migration report as it goes on the wire
priv struct WireMigrationResult {
  changes : Array[WireMigrationChange]
  breaking_count : Double
  sql : String
} derive(ToJson)

///|
/// Full migration pipeline: two models -> migration JSON
pub fn generate_migration(
  old_model : @moonmodel.Model,
  new_model : @moonmodel.Model,
) -> String {
  let report = diff_models(old_model, new_model)
  let sql = generate_sql_migration(old_model, new_model)
  let changes_arr : Array[WireMigrationChange] = []
  for c in report.changes {
    changes_arr.push(WireMigrationChange::{
      text: c.to_text(),
      breaking: c.is_breaking(),
    })
  }
  ToJson::to_json(WireMigrationResult::{
    changes: changes_arr,
    breaking_count: report.breaking_count.to_double(),
    sql,
  }).stringify()
}
