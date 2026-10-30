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
/// Check constraint description
fn check_desc(c : @moonmodel.Check) -> Array[String] {
  let parts = []
  match c.least {
    Some(v) => parts.push("least=\{v}")
    None => ()
  }
  match c.most {
    Some(v) => parts.push("most=\{v}")
    None => ()
  }
  match c.over {
    Some(v) => parts.push("over=\{v}")
    None => ()
  }
  match c.under {
    Some(v) => parts.push("under=\{v}")
    None => ()
  }
  match c.step {
    Some(v) => parts.push("step=\{v}")
    None => ()
  }
  match c.shortest {
    Some(v) => parts.push("shortest=\{v}")
    None => ()
  }
  match c.longest {
    Some(v) => parts.push("longest=\{v}")
    None => ()
  }
  match c.pattern {
    Some(v) => parts.push("pattern=\{v}")
    None => ()
  }
  match c.format {
    Some(v) => parts.push("format=\{v}")
    None => ()
  }
  if c.options.length() > 0 {
    parts.push("options[\{c.options.length()}]")
  }
  if c.distinct {
    parts.push("distinct")
  }
  if c.unique {
    parts.push("unique")
  }
  parts
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
        // Constraint changes
        let old_checks = check_desc(old_f.check)
        let new_checks = check_desc(new_f.check)
        for c in new_checks {
          if !old_checks.contains(c) {
            changes.push(ConstraintAdded(old_f.name, c))
          }
        }
        for c in old_checks {
          if !new_checks.contains(c) {
            changes.push(ConstraintRemoved(old_f.name, c))
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
