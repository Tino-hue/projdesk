// Constraint expression tests: arithmetic, builtins, error handling

// ---- Lexer: operator tokens ----

///|
test "expr: lexer produces operator tokens" {
  let (tokens, errors) = @main.lex("+ - * / %")
  assert_eq(errors.length(), 0)
  assert_eq(tokens[0].token, Plus)
  assert_eq(tokens[1].token, Minus)
  assert_eq(tokens[2].token, Star)
  assert_eq(tokens[3].token, Slash)
  assert_eq(tokens[4].token, Percent)
}

// ---- Block comments ----

///|
test "expr: block comment is lexed" {
  let (tokens, errors) = @main.lex("/* hello */")
  assert_eq(errors.length(), 0)
  match tokens[0].token {
    Comment(s) => assert_eq(s, " hello ")
    _ => abort("expected Comment")
  }
}

///|
test "expr: block comment spanning lines" {
  let (tokens, errors) = @main.lex("/* line1\nline2 */")
  assert_eq(errors.length(), 0)
  match tokens[0].token {
    Comment(s) => assert_true(s.contains("line2"))
    _ => abort("expected Comment")
  }
}

///|
test "expr: block comment does not swallow following code" {
  let (tokens, errors) = @main.lex("/* c */ model T")
  assert_eq(errors.length(), 0)
  // first token is the comment, then the model keyword
  match tokens[0].token {
    Comment(_) => ()
    _ => abort("expected Comment first")
  }
  assert_eq(tokens[1].token, KwModel)
}

///|
test "expr: unterminated block comment consumes to end" {
  let (_, errors) = @main.lex("/* never closed")
  // should not crash; lexer ends cleanly
  assert_eq(errors.length(), 0)
}

// ---- Expression evaluation ----

///|
test "expr: arithmetic evaluates" {
  let vars : Map[String, Double] = Map([])
  let n = match
    @main.eval_expr(@main.Num(2.0) |> expr_add(@main.Num(3.0)), vars) {
    Ok(v) => v
    Err(_) => -1.0
  }
  assert_eq(n, 5.0)
}

///|
fn expr_add(left : @main.Expr, right : @main.Expr) -> @main.Expr {
  @main.Binop("+", left, right)
}

///|
test "expr: multiplication evaluates" {
  let vars : Map[String, Double] = Map([])
  let n = match
    @main.eval_expr(@main.Binop("*", @main.Num(2.0), @main.Num(10.0)), vars) {
    Ok(v) => v
    Err(_) => -1.0
  }
  assert_eq(n, 20.0)
}

///|
test "expr: division evaluates" {
  let vars : Map[String, Double] = Map([])
  let n = match
    @main.eval_expr(@main.Binop("/", @main.Num(10.0), @main.Num(4.0)), vars) {
    Ok(v) => v
    Err(_) => -1.0
  }
  assert_eq(n, 2.5)
}

///|
test "expr: division by zero is an error" {
  let vars : Map[String, Double] = Map([])
  match
    @main.eval_expr(@main.Binop("/", @main.Num(1.0), @main.Num(0.0)), vars) {
    Ok(_) => abort("expected division by zero error")
    Err(e) => assert_eq(e, @main.DivByZero)
  }
}

///|
test "expr: builtins min and max" {
  let vars : Map[String, Double] = Map([])
  let lo = match
    @main.eval_expr(@main.Call("min", [@main.Num(3.0), @main.Num(7.0)]), vars) {
    Ok(v) => v
    Err(_) => -1.0
  }
  let hi = match
    @main.eval_expr(@main.Call("max", [@main.Num(3.0), @main.Num(7.0)]), vars) {
    Ok(v) => v
    Err(_) => -1.0
  }
  assert_eq(lo, 3.0)
  assert_eq(hi, 7.0)
}

///|
test "expr: builtin abs and ceil and floor" {
  let vars : Map[String, Double] = Map([])
  let a = match @main.eval_expr(@main.Call("abs", [@main.Num(-4.5)]), vars) {
    Ok(v) => v
    Err(_) => -1.0
  }
  let c = match @main.eval_expr(@main.Call("ceil", [@main.Num(4.2)]), vars) {
    Ok(v) => v
    Err(_) => -1.0
  }
  let f = match @main.eval_expr(@main.Call("floor", [@main.Num(4.8)]), vars) {
    Ok(v) => v
    Err(_) => -1.0
  }
  assert_eq(a, 4.5)
  assert_eq(c, 5.0)
  assert_eq(f, 4.0)
}

///|
test "expr: unknown function is an error" {
  let vars : Map[String, Double] = Map([])
  match @main.eval_expr(@main.Call("nope", [@main.Num(1.0)]), vars) {
    Ok(_) => abort("expected unknown function error")
    Err(e) => assert_eq(e, @main.UnknownFunc("nope"))
  }
}

///|
test "expr: wrong argument count is an error" {
  let vars : Map[String, Double] = Map([])
  match @main.eval_expr(@main.Call("min", [@main.Num(1.0)]), vars) {
    Ok(_) => abort("expected bad args error")
    Err(e) => assert_eq(e, @main.BadArgs("min"))
  }
}

///|
test "expr: unknown variable is an error" {
  let vars : Map[String, Double] = Map([])
  match @main.eval_expr(@main.Var("missing"), vars) {
    Ok(_) => abort("expected unknown variable error")
    Err(e) => assert_eq(e, @main.UnknownVar("missing"))
  }
}

// ---- Expression parsing in constraints ----

///|
test "expr: constraint accepts arithmetic expression" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  x: Text [longest=2*10]\n}",
  )
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 1)
}

///|
test "expr: constraint accepts function call" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  x: Text [longest=min(5,10)]\n}",
  )
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 1)
}

///|
test "expr: negative literal in constraint" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  x: Real [least=-1]\n}",
  )
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 1)
}

///|
test "expr: arithmetic with precedence parses" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  x: Real [least=1+2*3]\n}",
  )
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 1)
}

///|
test "expr: division by zero in constraint reports error" {
  let (_, _, errors) = @main.dsl_parse("model T {\n  x: Real [least=1/0]\n}")
  assert_true(errors.length() > 0)
}

///|
test "expr: unknown function in constraint reports error" {
  let (_, _, errors) = @main.dsl_parse(
    "model T {\n  x: Real [least=nope(1)]\n}",
  )
  assert_true(errors.length() > 0)
}

///|
test "expr: expression result reaches the projection" {
  let (output, errors) = @main.dsl_project(
    "model T {\n  x: Text [longest=2*10]\n}",
  )
  assert_eq(errors.length(), 0)
  // 2 * 10 = 20 must appear as maxLength
  assert_true(output.contains("maxLength"))
  assert_true(output.contains("20"))
}
