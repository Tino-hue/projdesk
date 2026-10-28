// Constraint expression AST and evaluator
// Supports arithmetic and function calls in constraint values

///|
/// Expression AST for constraint values
pub(all) enum Expr {
  Num(Double)
  Var(String)
  /// Field reference: other_field.constraint_name (e.g. `a.least`)
  FieldRef(String, String)
  Binop(String, Expr, Expr)
  Call(String, Array[Expr])
} derive(Eq, Debug)

///|
pub extend Expr with Eq::{equal, not_equal}

///|
pub extend Expr with Debug::{to_repr}

///|
/// Evaluation error
pub(all) enum ExprError {
  UnknownVar(String)
  UnknownFunc(String)
  BadArgs(String)
  DivByZero
  /// The expression refers to another field's bound, which is not resolved
  /// yet. The reference is kept so it can be resolved once that field is
  /// known; it is not an error on its own.
  UnresolvedRef(String, String)
} derive(Eq, Debug)

///|
pub extend ExprError with Eq::{equal, not_equal}

///|
pub extend ExprError with Debug::{to_repr}

///|
pub fn ExprError::to_text(self : ExprError) -> String {
  match self {
    UnknownVar(name) => "unknown variable '" + name + "'"
    UnknownFunc(name) => "unknown function '" + name + "'"
    BadArgs(name) => "wrong number of arguments to '" + name + "'"
    DivByZero => "division by zero"
    UnresolvedRef(field, constraint) =>
      "constraint reference '" +
      field +
      "." +
      constraint +
      "' is not resolved yet"
  }
}

///|
/// Built-in functions available in expressions
/// - min(a, b), max(a, b) — two arguments
/// - abs(a) — one argument
/// - ceil(a), floor(a) — one argument
fn call_builtin(
  name : String,
  args : Array[Expr],
  env : Env,
) -> Result[Double, ExprError] {
  match name {
    "min" => {
      if args.length() != 2 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr_in(args[0], env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let b = match eval_expr_in(args[1], env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(if a < b { a } else { b })
    }
    "max" => {
      if args.length() != 2 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr_in(args[0], env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let b = match eval_expr_in(args[1], env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(if a > b { a } else { b })
    }
    "abs" => {
      if args.length() != 1 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr_in(args[0], env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(if a < 0.0 { -a } else { a })
    }
    "ceil" => {
      if args.length() != 1 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr_in(args[0], env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(a.ceil())
    }
    "floor" => {
      if args.length() != 1 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr_in(args[0], env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(a.floor())
    }
    _ => Err(UnknownFunc(name))
  }
}

///|
/// Evaluation environment: plain variables plus field constraint references
pub(all) struct Env {
  vars : Map[String, Double]
  /// field name -> (constraint name -> value)
  fields : Map[String, Map[String, Double]]
} derive(Eq, Debug)

///|
pub extend Env with Eq::{equal, not_equal}

///|
pub extend Env with Debug::{to_repr}

///|
/// Look up a field's constraint value
fn env_field(
  env : Env,
  field : String,
  constraint : String,
) -> Result[Double, ExprError] {
  match env.fields.get(field) {
    Some(constraints) =>
      match constraints.get(constraint) {
        Some(v) => Ok(v)
        // the field exists but does not carry this constraint: the resolver
        // decides whether that is a mistake or a reference to a later field
        None => Err(UnresolvedRef(field, constraint))
      }
    None => Err(UnresolvedRef(field, constraint))
  }
}

///|
/// Evaluate an expression in an environment
pub fn eval_expr_in(expr : Expr, env : Env) -> Result[Double, ExprError] {
  match expr {
    Num(n) => Ok(n)
    Var(name) =>
      match env.vars.get(name) {
        Some(v) => Ok(v)
        None => Err(UnknownVar(name))
      }
    FieldRef(field, constraint) => env_field(env, field, constraint)
    Binop(op, left, right) => {
      let a = match eval_expr_in(left, env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let b = match eval_expr_in(right, env) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      match op {
        "+" => Ok(a + b)
        "-" => Ok(a - b)
        "*" => Ok(a * b)
        "/" => if b == 0.0 { Err(DivByZero) } else { Ok(a / b) }
        "%" => if b == 0.0 { Err(DivByZero) } else { Ok(a % b) }
        _ => Ok(a)
      }
    }
    Call(name, args) => call_builtin(name, args, env)
  }
}

///|
/// Evaluate an expression with a variable environment (no field references)
pub fn eval_expr(
  expr : Expr,
  vars : Map[String, Double],
) -> Result[Double, ExprError] {
  eval_expr_in(expr, { vars, fields: Map([]), })
}

///|
/// The field reference this expression depends on, if any
pub fn Expr::dependency(self : Expr) -> (String, String)? {
  match self {
    FieldRef(field, constraint) => Some((field, constraint))
    Binop(_, left, right) =>
      match left.dependency() {
        Some(d) => Some(d)
        None => right.dependency()
      }
    Call(_, args) => {
      for a in args {
        match a.dependency() {
          Some(d) => return Some(d)
          None => ()
        }
      }
      None
    }
    _ => None
  }
}

///|
/// Render an expression back to source text (for pretty-printing)
pub fn Expr::to_source(self : Expr) -> String {
  match self {
    Num(n) => n.to_string()
    Var(name) => name
    FieldRef(field, constraint) => field + "." + constraint
    Binop(op, left, right) =>
      "(" + left.to_source() + " " + op + " " + right.to_source() + ")"
    Call(name, args) => {
      let parts = args.map(fn(a) { a.to_source() })
      name + "(" + parts.join(", ") + ")"
    }
  }
}
