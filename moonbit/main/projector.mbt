// Pluggable Projector trait and typed DropReason
// This is the MoonBit depth showcase: trait + ADT + pattern matching

///|
/// Typed drop reason 鈥?why a constraint cannot be carried by a target
pub(all) enum DropReason {
  UniqueNotCarried(String)
  PatternNotCarried(String)
  FormatNotCarried(String)
  StepNotCarried(String)
  DistinctNotCarried(String)
  BoundsNotCarried(String, String)
  LengthNotCarried(String)
  OptionsNotCarried(String)
  FieldNotCarried(String, String, String)
} derive(Eq, Debug)

///|
pub extend DropReason with Eq::{equal, not_equal}

///|
pub extend DropReason with Debug::{to_repr}

///|
/// Human-readable description of a drop reason
pub fn DropReason::to_text(self : DropReason) -> String {
  match self {
    UniqueNotCarried(f) => "\{f}.unique: record-level unique is not expressible"
    PatternNotCarried(f) => "\{f}.pattern: regex constraint not supported"
    FormatNotCarried(f) => "\{f}.format: format is documentation semantics, not a constraint"
    StepNotCarried(f) => "\{f}.step: multipleOf predicate not available"
    DistinctNotCarried(f) => "\{f}.distinct: list dedup has different semantics"
    BoundsNotCarried(f, b) => "\{f}.\{b}: numeric bounds not supported"
    LengthNotCarried(f) => "\{f}: length constraints not supported"
    OptionsNotCarried(f) => "\{f}.options: closed set not auto-generated as enum"
    FieldNotCarried(f, k, why) => "\{f} (\{k}): \{why}"
  }
}

///|
/// Which constraint was dropped (for the UI badge)
pub fn DropReason::constraint(self : DropReason) -> String {
  match self {
    UniqueNotCarried(_) => "unique"
    PatternNotCarried(_) => "pattern"
    FormatNotCarried(_) => "format"
    StepNotCarried(_) => "step"
    DistinctNotCarried(_) => "distinct"
    BoundsNotCarried(_, b) => b
    LengthNotCarried(_) => "length"
    OptionsNotCarried(_) => "options"
    FieldNotCarried(_, k, _) => k
  }
}

///|
/// Which field was affected
pub fn DropReason::field(self : DropReason) -> String {
  match self {
    UniqueNotCarried(f) => f
    PatternNotCarried(f) => f
    FormatNotCarried(f) => f
    StepNotCarried(f) => f
    DistinctNotCarried(f) => f
    BoundsNotCarried(f, _) => f
    LengthNotCarried(f) => f
    OptionsNotCarried(f) => f
    FieldNotCarried(f, _, _) => f
  }
}

///|
/// Pluggable projector trait 鈥?each target implements this
pub(open) trait Projector {
  /// Target name (e.g. "JSON Schema 2020-12")
  fn target_name(Self) -> String
  /// Project a model into target artifact + list of drop reasons
  fn project(
    Self,
    model : @moonmodel.Model,
    known : Array[@moonmodel.Model],
  ) -> (String, Array[DropReason])
}

///|
/// JSON Schema projector
pub(all) struct JsonProjector {
}

///|
pub impl Projector for JsonProjector with target_name(self) -> String {
  "JSON Schema 2020-12"
}

///|
pub impl Projector for JsonProjector with project(
  self,
  model,
  known,
) -> (String, Array[DropReason]) {
  let doc = @json.document(model, known~)
  let text = doc.stringify(indent=2)
  let drops = []
  for f in model.fields {
    if f.check.unique {
      drops.push(UniqueNotCarried(f.name))
    }
  }
  (text, drops)
}

///|
/// OpenAPI projector
pub(all) struct OpenApiProj {
}

///|
pub impl Projector for OpenApiProj with target_name(self) -> String {
  "OpenAPI Schema Object"
}

///|
pub impl Projector for OpenApiProj with project(
  self,
  model,
  _known,
) -> (String, Array[DropReason]) {
  let schema = @open.of(model, dialect=OpenApi30)
  let text = schema.stringify(indent=2)
  let drops = []
  for f in model.fields {
    if f.check.unique {
      drops.push(UniqueNotCarried(f.name))
    }
  }
  (text, drops)
}

///|
/// SQL projector
pub(all) struct SqlProj {
  dialect : @sql.Dialect
}

///|
pub impl Projector for SqlProj with target_name(self) -> String {
  "SQL DDL"
}

///|
pub impl Projector for SqlProj with project(
  self,
  model,
  _known,
) -> (String, Array[DropReason]) {
  let ddl = @sql.table(model, dialect=self.dialect)
  let (_cols, skipped) = @sql.of(model, dialect=self.dialect)
  let drops = []
  for s in skipped {
    drops.push(FieldNotCarried(s.field, "field", s.why))
  }
  for f in model.fields {
    let is_skipped = skipped.any(fn(s) { s.field == f.name })
    if !is_skipped {
      if f.check.pattern is Some(_) {
        drops.push(PatternNotCarried(f.name))
      }
      if f.check.format is Some(_) {
        drops.push(FormatNotCarried(f.name))
      }
      if f.check.step is Some(_) {
        drops.push(StepNotCarried(f.name))
      }
      if f.check.distinct {
        drops.push(DistinctNotCarried(f.name))
      }
    }
  }
  (ddl, drops)
}

///|
/// GraphQL SDL projector
pub(all) struct GraphqlProj {
}

///|
pub impl Projector for GraphqlProj with target_name(self) -> String {
  "GraphQL SDL"
}

///|
pub impl Projector for GraphqlProj with project(
  self,
  model,
  known,
) -> (String, Array[DropReason]) {
  let all : Array[@moonmodel.Model] = [model]
  for k in known {
    all.push(k)
  }
  let text = @sdl.document(all[:])
  let (_s, skipped) = @sdl.of(model)
  let drops = []
  for s in skipped {
    drops.push(FieldNotCarried(s.field, "field", s.why))
  }
  for f in model.fields {
    let is_skipped = skipped.any(fn(s) { s.field == f.name })
    if !is_skipped {
      let c = f.check
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
      if c.shortest is Some(_) {
        drops.push(LengthNotCarried(f.name))
      }
      if c.longest is Some(_) {
        drops.push(LengthNotCarried(f.name))
      }
      if c.pattern is Some(_) {
        drops.push(PatternNotCarried(f.name))
      }
      if c.format is Some(_) {
        drops.push(FormatNotCarried(f.name))
      }
      if c.options.length() > 0 {
        drops.push(OptionsNotCarried(f.name))
      }
      if c.distinct {
        drops.push(DistinctNotCarried(f.name))
      }
      if c.unique {
        drops.push(UniqueNotCarried(f.name))
      }
    }
  }
  (text, drops)
}




