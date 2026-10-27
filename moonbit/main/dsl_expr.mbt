// Constraint expression AST and evaluator
// Supports arithmetic and function calls in constraint values

///|
/// Expression AST for constraint values
pub(all) enum Expr {
  Num(Double)
  Var(String)
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
  vars : Map[String, Double],
) -> Result[Double, ExprError] {
  match name {
    "min" => {
      if args.length() != 2 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr(args[0], vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let b = match eval_expr(args[1], vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(if a < b { a } else { b })
    }
    "max" => {
      if args.length() != 2 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr(args[0], vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let b = match eval_expr(args[1], vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(if a > b { a } else { b })
    }
    "abs" => {
      if args.length() != 1 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr(args[0], vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(if a < 0.0 { -a } else { a })
    }
    "ceil" => {
      if args.length() != 1 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr(args[0], vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(a.ceil())
    }
    "floor" => {
      if args.length() != 1 {
        return Err(BadArgs(name))
      }
      let a = match eval_expr(args[0], vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(a.floor())
    }
    _ => Err(UnknownFunc(name))
  }
}

///|
/// Evaluate an expression with a variable environment
pub fn eval_expr(
  expr : Expr,
  vars : Map[String, Double],
) -> Result[Double, ExprError] {
  match expr {
    Num(n) => Ok(n)
    Var(name) =>
      match vars.get(name) {
        Some(v) => Ok(v)
        None => Err(UnknownVar(name))
      }
    Binop(op, left, right) => {
      let a = match eval_expr(left, vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let b = match eval_expr(right, vars) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      match op {
        "+" => Ok(a + b)
        "-" => Ok(a - b)
        "*" => Ok(a * b)
        "/" =>
          if b == 0.0 {
            Err(DivByZero)
          } else {
            Ok(a / b)
          }
        "%" =>
          if b == 0.0 {
            Err(DivByZero)
          } else {
            Ok(a % b)
          }
        _ => Ok(a)
      }
    }
    Call(name, args) => call_builtin(name, args, vars)
  }
}

///|
/// Render an expression back to source text (for pretty-printing)
pub fn Expr::to_source(self : Expr) -> String {
  match self {
    Num(n) => n.to_string()
    Var(name) => name
    Binop(op, left, right) =>
      "(" + left.to_source() + " " + op + " " + right.to_source() + ")"
    Call(name, args) => {
      let parts = args.map(fn(a) { a.to_source() })
      name + "(" + parts.join(", ") + ")"
    }
  }
}
