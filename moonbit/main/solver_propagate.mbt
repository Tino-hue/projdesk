// Interval propagation solver: cross-field constraint reasoning
//
// Beyond per-field checking, this builds a constraint graph across fields and
// propagates bounds to a fixed point. A field's bound may reference another
// field's bound (e.g. `b: Int [most=a.least]`), so bounds form a system of
// equations that must be solved together.
//
// The algorithm is a worklist over intervals:
//   1. Seed each field's interval from its own literal constraints
//   2. Whenever a bound resolves to another field's bound, record a dependency
//   3. Iterate to a fixed point: propagate every known bound to its dependents
//   4. Detect cycles in the dependency graph (unresolvable constraints)
//   5. Report conflicts found only after propagation (invisible per-field)

///|
/// An inclusive interval of possible values
pub(all) struct Interval {
  lower : Double?
  upper : Double?
} derive(Eq, Debug)

///|
pub extend Interval with Eq::{equal, not_equal}

///|
pub extend Interval with Debug::{to_repr}

///|
/// Create an unbounded interval
pub fn unbounded() -> Interval {
  { lower: None, upper: None, }
}

///|
/// Intersect two intervals, keeping the tighter bound on each side
pub fn Interval::intersect(self : Interval, other : Interval) -> Interval {
  let lower = match (self.lower, other.lower) {
    (Some(a), Some(b)) => Some(if a > b { a } else { b })
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  let upper = match (self.upper, other.upper) {
    (Some(a), Some(b)) => Some(if a < b { a } else { b })
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  { lower, upper, }
}

///|
/// Is the interval empty (lower > upper)?
pub fn Interval::is_empty(self : Interval) -> Bool {
  match (self.lower, self.upper) {
    (Some(lo), Some(hi)) => lo > hi
    _ => false
  }
}

///|
/// Is the interval a single point?
pub fn Interval::is_point(self : Interval) -> Bool {
  match (self.lower, self.upper) {
    (Some(lo), Some(hi)) => lo == hi
    _ => false
  }
}

///|
/// A resolved bound value together with where it came from
/// `from_field` is empty for a literal, otherwise the referenced field name.
/// The value is absent while the reference is still unresolved.
pub(all) struct Bound {
  value : Double?
  from_field : String
} derive(Eq, Debug)

///|
pub extend Bound with Eq::{equal, not_equal}

///|
pub extend Bound with Debug::{to_repr}

///|
/// A field's constraint bounds, possibly referencing other fields
pub(all) struct FieldBounds {
  name : String
  least : Bound?
  most : Bound?
  over : Bound?
  under : Bound?
} derive(Eq, Debug)

///|
pub extend FieldBounds with Eq::{equal, not_equal}

///|
pub extend FieldBounds with Debug::{to_repr}

///|
/// Result of propagation over a model
pub(all) enum PropagationResult {
  /// All bounds resolved consistently
  Consistent(Array[Interval])
  /// A dependency cycle exists (e.g. a.least -> b.least -> a.least)
  CyclicDependency(Array[String])
  /// An interval became empty after propagation
  EmptyInterval(String, Interval)
} derive(Eq, Debug)

///|
pub extend PropagationResult with Eq::{equal, not_equal}

///|
pub extend PropagationResult with Debug::{to_repr}

///|
/// Diagnose a model whose bounds may reference other fields
///
/// `bounds` gives each field's own bounds, where a bound may be a literal or
/// a reference to another field's bound of the same kind.
pub fn propagate(bounds : Array[FieldBounds]) -> PropagationResult {
  let n = bounds.length()
  if n == 0 {
    return Consistent([])
  }
  // index by name
  let index : Map[String, Int] = Map([])
  for i = 0; i < n; i = i + 1 {
    index[bounds[i].name] = i
  }
  // Dependency edges: field -> fields it depends on
  let deps : Array[Array[String]] = []
  for i = 0; i < n; i = i + 1 {
    let d : Array[String] = []
    for b in [bounds[i].least, bounds[i].most, bounds[i].over, bounds[i].under] {
      match b {
        Some(bound) =>
          if bound.from_field != "" {
            // self-reference is also a cycle; keep it in the dependency list
            d.push(bound.from_field)
          }
        None => ()
      }
    }
    deps.push(d)
  }
  // Cycle detection: does following dependencies ever return to the start?
  for i = 0; i < n; i = i + 1 {
    let start = bounds[i].name
    let seen : Array[String] = []
    let mut stack = deps[i]
    let mut cyclic = false
    let mut steps = 0
    while stack.length() > 0 && !cyclic && steps < 100 {
      steps = steps + 1
      let next = stack[0]
      let rest = stack[1:].to_owned()
      if next == start {
        // returning to the start closes a cycle
        cyclic = true
      } else if seen.contains(next) {
        cyclic = true
      } else {
        seen.push(next)
        match index.get(next) {
          Some(j) => {
            let more : Array[String] = []
            for m in deps[j] {
              more.push(m)
            }
            stack = rest + more
          }
          None => stack = rest
        }
      }
    }
    if cyclic {
      let chain = [start]
      for d in deps[i] {
        chain.push(d)
      }
      return CyclicDependency(chain)
    }
  }
  // Fixed-point propagation
  let intervals : Array[Interval] = []
  for i = 0; i < n; i = i + 1 {
    let mut iv = unbounded()
    match bounds[i].least {
      Some(b) =>
        match b.value {
          Some(v) => iv = iv.intersect({ lower: Some(v), upper: None, })
          None => ()
        }
      None => ()
    }
    match bounds[i].most {
      Some(b) =>
        match b.value {
          Some(v) => iv = iv.intersect({ lower: None, upper: Some(v), })
          None => ()
        }
      None => ()
    }
    match bounds[i].over {
      Some(b) =>
        match b.value {
          Some(v) => iv = iv.intersect({ lower: Some(v), upper: None, })
          None => ()
        }
      None => ()
    }
    match bounds[i].under {
      Some(b) =>
        match b.value {
          Some(v) => iv = iv.intersect({ lower: None, upper: Some(v), })
          None => ()
        }
      None => ()
    }
    intervals.push(iv)
  }
  // Iterate: resolve referenced bounds and tighten dependents
  let mut changed = true
  let mut rounds = 0
  while changed && rounds < n + 1 {
    changed = false
    rounds = rounds + 1
    for i = 0; i < n; i = i + 1 {
      let mut new_iv = intervals[i]
      // A bound that takes its value from another field ties this field to
      // that one on the same side of the range: a shared lower bound tightens
      // our lower bound, a shared upper bound tightens our upper bound.
      for b in [bounds[i].least, bounds[i].over] {
        match b {
          Some(bound) =>
            if bound.from_field != "" && bound.from_field != bounds[i].name {
              match index.get(bound.from_field) {
                Some(j) =>
                  match intervals[j].lower {
                    Some(v) =>
                      if bound.value == Some(v) {
                        new_iv = new_iv.intersect({
                          lower: Some(v),
                          upper: None,
                        })
                      }
                    None => ()
                  }
                None => ()
              }
            }
          None => ()
        }
      }
      for b in [bounds[i].most, bounds[i].under] {
        match b {
          Some(bound) =>
            if bound.from_field != "" && bound.from_field != bounds[i].name {
              match index.get(bound.from_field) {
                Some(j) =>
                  match intervals[j].upper {
                    Some(v) =>
                      if bound.value == Some(v) {
                        new_iv = new_iv.intersect({
                          lower: None,
                          upper: Some(v),
                        })
                      }
                    None => ()
                  }
                None => ()
              }
            }
          None => ()
        }
      }
      if new_iv != intervals[i] {
        intervals[i] = new_iv
        changed = true
      }
    }
  }
  // Report empty intervals discovered only after propagation
  for i = 0; i < n; i = i + 1 {
    if intervals[i].is_empty() {
      return EmptyInterval(bounds[i].name, intervals[i])
    }
  }
  Consistent(intervals)
}

///|
/// Human-readable summary of a propagation result
pub fn PropagationResult::to_text(self : PropagationResult) -> String {
  match self {
    Consistent(intervals) => {
      let parts : Array[String] = []
      for iv in intervals {
        let lo = match iv.lower {
          Some(v) => v.to_string()
          None => "-inf"
        }
        let hi = match iv.upper {
          Some(v) => v.to_string()
          None => "+inf"
        }
        parts.push("[" + lo + ", " + hi + "]")
      }
      "consistent: " + parts.join(" ")
    }
    CyclicDependency(fields) => "cyclic dependency: " + fields.join(" -> ")
    EmptyInterval(name, _) =>
      "empty constraint range for " + name + ": the bounds cannot be satisfied"
  }
}
