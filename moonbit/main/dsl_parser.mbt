// DSL Parser: Token stream -> AST
// Recursive descent parser for ProjDesk modeling language

///|
/// AST node for a model definition
pub(all) struct AstModel {
  name : String
  fields : Array[AstField]
  doc : String
} derive(Eq, Debug)

///|
pub extend AstCheck with Eq::{equal, not_equal}

///|
pub extend AstCheck with Debug::{to_repr}

///|
pub extend AstField with Eq::{equal, not_equal}

///|
pub extend AstField with Debug::{to_repr}

///|
pub extend AstModel with Eq::{equal, not_equal}

///|
pub extend AstModel with Debug::{to_repr}

///|
pub extend AstType with Eq::{equal, not_equal}

///|
pub extend AstType with Debug::{to_repr}

///|
pub extend ParseError with Eq::{equal, not_equal}

///|
pub extend ParseError with Debug::{to_repr}

///|

///|
/// AST node for a field definition
pub(all) struct AstField {
  name : String
  kind : AstType
  required : Bool
  nullable : Bool
  doc : String
  checks : Array[AstCheck]
  attrs : Array[String]
} derive(Eq, Debug)

///|

///|
/// AST type representation
pub(all) enum AstType {
  Named(String)
  ListOf(AstType)
  DictOf(AstType)
  RefTo(String)
  Nested(AstModel)
} derive(Eq, Debug)

///|

///|
/// A numeric constraint bound. The expression is kept so the printer can
/// reproduce the source, and the value is filled in once the expression has
/// been evaluated — a reference to another field may only resolve later.
pub(all) struct AstBound {
  value : Double?
  expr : Expr
} derive(Eq, Debug)

///|
pub extend AstBound with Eq::{equal, not_equal}

///|
pub extend AstBound with Debug::{to_repr}

///|
/// AST constraint representation
pub(all) enum AstCheck {
  Least(AstBound)
  Most(AstBound)
  Over(AstBound)
  Under(AstBound)
  Step(AstBound)
  Shortest(AstBound)
  Longest(AstBound)
  Pattern(String)
  Format(String)
  Options(Array[String])
  Distinct
  Unique
} derive(Eq, Debug)

///|

///|
/// Parse error with position
pub(all) struct ParseError {
  msg : String
  line : Int32
  col : Int32
} derive(Eq, Debug)

///|

///|
pub fn ParseError::to_text(self : ParseError) -> String {
  "line \{self.line}:\{self.col}: \{self.msg}"
}

///|
/// Parser state (mutable via Ref)
pub(all) struct Parser {
  tokens : Array[Lexeme]
  pos : Ref[Int32]
  /// Resolved numeric constraints of the current model, keyed by field name.
  /// Lets a later field reference an earlier one: `b: Int32 [over=a.least]`.
  field_env : Ref[Map[String, Map[String, Double]]]
}

///|
/// Peek at current token
fn peek(p : Parser) -> Token {
  if p.pos.val < p.tokens.length() {
    p.tokens[p.pos.val].token
  } else {
    Eof
  }
}

///|
/// Consume current token and advance
fn advance(p : Parser) -> Token {
  let t = peek(p)
  p.pos.val = p.pos.val + 1
  t
}

///|
/// Get current position for error reporting
fn cur_pos(p : Parser) -> (Int32, Int32) {
  if p.pos.val < p.tokens.length() {
    (p.tokens[p.pos.val].line, p.tokens[p.pos.val].col)
  } else {
    (0, 0)
  }
}

///|
/// Skip newlines

///|
/// Skip newlines and comments
fn skip_newlines(p : Parser) -> Unit {
  let mut keep_going = true
  while keep_going {
    match peek(p) {
      Newline => advance(p) |> ignore
      Comment(_) => advance(p) |> ignore
      _ => keep_going = false
    }
  }
}

///|
/// Expect a specific token, return error if mismatch
fn expect(p : Parser, expected : Token) -> ParseError? {
  let actual = peek(p)
  if actual == expected {
    advance(p) |> ignore
    None
  } else {
    let (l, c) = cur_pos(p)
    Some({
      msg: "expected \{expected.to_text()}, got \{actual.to_text()}",
      line: l,
      col: c,
    })
  }
}

///|
/// Parse a model definition
/// grammar: model IDENT '{' field* '}'
fn dsl_parse_model(p : Parser) -> (AstModel?, Array[ParseError]) {
  let errors = []
  // each model has its own constraint namespace
  p.field_env.val = Map([])
  // expect 'model'
  match expect(p, KwModel) {
    Some(e) => return (None, [e])
    None => ()
  }
  skip_newlines(p)
  // expect model name
  let name = match advance(p) {
    Ident(s) => s
    _ => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: "expected model name", line: l, col: c, })
      return (None, errors)
    }
  }
  skip_newlines(p)
  // expect '{'
  match expect(p, LBrace) {
    Some(e) => {
      errors.push(e)
      return (None, errors)
    }
    None => ()
  }
  // parse fields
  let fields : Array[AstField] = []
  skip_newlines(p)
  while peek(p) != RBrace && peek(p) != Eof {
    let (field, field_errors) = dsl_parse_field(p)
    for e in field_errors {
      errors.push(e)
    }
    match field {
      Some(f) => fields.push(f)
      None => ()
    }
    skip_newlines(p)
  }
  // expect '}'
  match expect(p, RBrace) {
    Some(e) => errors.push(e)
    None => ()
  }
  if errors.length() > 0 {
    (None, errors)
  } else {
    (Some({ name, fields, doc: "", }), errors)
  }
}

///|
/// Parse a field definition
/// grammar: IDENT ':' type attr* check*
fn dsl_parse_field(p : Parser) -> (AstField?, Array[ParseError]) {
  let errors = []
  let name = match advance(p) {
    Ident(s) => s
    _ => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: "expected field name", line: l, col: c, })
      return (None, errors)
    }
  }
  skip_newlines(p)
  // expect ':'
  match expect(p, Colon) {
    Some(e) => {
      errors.push(e)
      return (None, errors)
    }
    None => ()
  }
  skip_newlines(p)
  // parse type
  let (kind, type_errors) = dsl_parse_type(p)
  for e in type_errors {
    errors.push(e)
  }
  // parse attributes and checks
  let checks : Array[AstCheck] = []
  let attrs : Array[String] = []
  let mut required = true
  let mut nullable = false
  let mut done = false
  while !done {
    skip_newlines(p)
    match peek(p) {
      At => {
        advance(p) |> ignore
        match advance(p) {
          Ident(s) =>
            match s {
              "optional" => required = false
              "nullable" => nullable = true
              "unique" => checks.push(Unique)
              "distinct" => checks.push(Distinct)
              _ => attrs.push(s)
            }
          _ => {
            let (l, c) = cur_pos(p)
            errors.push({
              msg: "expected attribute name after @",
              line: l,
              col: c,
            })
          }
        }
      }
      LBracket => {
        advance(p) |> ignore
        skip_newlines(p)
        while peek(p) != RBracket && peek(p) != Eof {
          let (check, check_errors) = dsl_parse_check(p, name)
          for e in check_errors {
            errors.push(e)
          }
          match check {
            Some(ch) => checks.push(ch)
            None => ()
          }
          skip_newlines(p)
          if peek(p) == Comma {
            advance(p) |> ignore
            skip_newlines(p)
          }
        }
        match expect(p, RBracket) {
          Some(e) => errors.push(e)
          None => ()
        }
      }
      _ => done = true
    }
  }
  if errors.length() > 0 {
    (None, errors)
  } else {
    (Some({ name, kind, required, nullable, doc: "", checks, attrs, }), errors)
  }
}

///|
/// Parse a type expression
fn dsl_parse_type(p : Parser) -> (AstType, Array[ParseError]) {
  let errors = []
  match advance(p) {
    KwRef => {
      // Ref(ModelName)
      match expect(p, LParen) {
        Some(e) => errors.push(e)
        None => ()
      }
      let target = match advance(p) {
        Ident(s) => s
        _ => {
          let (l, c) = cur_pos(p)
          errors.push({ msg: "expected model name in Ref()", line: l, col: c, })
          ""
        }
      }
      match expect(p, RParen) {
        Some(e) => errors.push(e)
        None => ()
      }
      (RefTo(target), errors)
    }
    KwList => {
      // List(inner)
      match expect(p, LParen) {
        Some(e) => errors.push(e)
        None => ()
      }
      let (inner, inner_errors) = dsl_parse_type(p)
      for e in inner_errors {
        errors.push(e)
      }
      match expect(p, RParen) {
        Some(e) => errors.push(e)
        None => ()
      }
      (ListOf(inner), errors)
    }
    KwDict => {
      // Dict(inner)
      match expect(p, LParen) {
        Some(e) => errors.push(e)
        None => ()
      }
      let (inner, inner_errors) = dsl_parse_type(p)
      for e in inner_errors {
        errors.push(e)
      }
      match expect(p, RParen) {
        Some(e) => errors.push(e)
        None => ()
      }
      (DictOf(inner), errors)
    }
    KwNest => {
      // Nest { field: Type, ... } — inline nested model
      match expect(p, LBrace) {
        Some(e) => errors.push(e)
        None => ()
      }
      let inner_fields : Array[AstField] = []
      skip_newlines(p)
      while peek(p) != RBrace && peek(p) != Eof {
        let (field, field_errors) = dsl_parse_field(p)
        for e in field_errors {
          errors.push(e)
        }
        match field {
          Some(f) => inner_fields.push(f)
          None => ()
        }
        skip_newlines(p)
        if peek(p) == Comma {
          advance(p) |> ignore
          skip_newlines(p)
        }
      }
      match expect(p, RBrace) {
        Some(e) => errors.push(e)
        None => ()
      }
      // The annotation is needed because the wire shape of a model carries the
      // same three fields as the AST model, so the literal would be ambiguous.
      let nested : AstModel = { name: "", fields: inner_fields, doc: "", }
      (Nested(nested), errors)
    }
    Ident(s) => (Named(s), errors)
    _ => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: "expected type name", line: l, col: c, })
      (Named("Text"), errors)
    }
  }
}

///|
/// Parse a primary expression: number, variable, or function call
fn dsl_parse_expr_primary(p : Parser) -> (Expr?, Array[ParseError]) {
  let errors = []
  match advance(p) {
    Number(n) => (Some(Num(n)), errors)
    Ident(name) =>
      // function call?
      if peek(p) == LParen {
        match expect(p, LParen) {
          Some(e) => errors.push(e)
          None => ()
        }
        let args : Array[Expr] = []
        skip_newlines(p)
        while peek(p) != RParen && peek(p) != Eof {
          let (arg, arg_errors) = dsl_parse_expr(p)
          for e in arg_errors {
            errors.push(e)
          }
          match arg {
            Some(a) => args.push(a)
            None => ()
          }
          skip_newlines(p)
          if peek(p) == Comma {
            advance(p) |> ignore
            skip_newlines(p)
          }
        }
        match expect(p, RParen) {
          Some(e) => errors.push(e)
          None => ()
        }
        (Some(Call(name, args)), errors)
      } else if peek(p) == Dot {
        // field reference: other_field.constraint
        advance(p) |> ignore
        match advance(p) {
          Ident(constraint) => (Some(FieldRef(name, constraint)), errors)
          _ => {
            let (l, c) = cur_pos(p)
            errors.push({
              msg: "expected constraint name after '.'",
              line: l,
              col: c,
            })
            (None, errors)
          }
        }
      } else {
        (Some(Var(name)), errors)
      }
    Minus => {
      // unary minus
      let (operand, operand_errors) = dsl_parse_expr_primary(p)
      for e in operand_errors {
        errors.push(e)
      }
      match operand {
        Some(Num(n)) => (Some(Num(-n)), errors)
        Some(other) => (Some(Binop("-", Num(0.0), other)), errors)
        None => (None, errors)
      }
    }
    LParen => {
      let (inner, inner_errors) = dsl_parse_expr(p)
      for e in inner_errors {
        errors.push(e)
      }
      match expect(p, RParen) {
        Some(e) => errors.push(e)
        None => ()
      }
      (inner, errors)
    }
    _ => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: "expected expression", line: l, col: c, })
      (None, errors)
    }
  }
}

///|
/// Parse a term: primary followed by * / %
fn dsl_parse_expr_term(p : Parser) -> (Expr?, Array[ParseError]) {
  let errors = []
  let (left0, left_errors) = dsl_parse_expr_primary(p)
  for e in left_errors {
    errors.push(e)
  }
  let mut left = left0
  let mut keep_going = true
  while keep_going {
    match peek(p) {
      Star | Slash | Percent => {
        let op = match advance(p) {
          Star => "*"
          Slash => "/"
          _ => "%"
        }
        let (right, right_errors) = dsl_parse_expr_primary(p)
        for e in right_errors {
          errors.push(e)
        }
        match (left, right) {
          (Some(l), Some(r)) => left = Some(Binop(op, l, r))
          _ => left = None
        }
      }
      _ => keep_going = false
    }
  }
  (left, errors)
}

///|
/// Parse a full expression: term followed by + -
fn dsl_parse_expr(p : Parser) -> (Expr?, Array[ParseError]) {
  let errors = []
  let (left0, left_errors) = dsl_parse_expr_term(p)
  for e in left_errors {
    errors.push(e)
  }
  let mut left = left0
  let mut keep_going = true
  while keep_going {
    match peek(p) {
      Plus | Minus => {
        let op = match advance(p) {
          Plus => "+"
          _ => "-"
        }
        let (right, right_errors) = dsl_parse_expr_term(p)
        for e in right_errors {
          errors.push(e)
        }
        match (left, right) {
          (Some(l), Some(r)) => left = Some(Binop(op, l, r))
          _ => left = None
        }
      }
      _ => keep_going = false
    }
  }
  (left, errors)
}

///|
/// Build a constraint bound from its expression. A reference to a field that
/// has not been seen yet stays unresolved: the resolver settles it once the
/// whole model is known.
fn make_bound(p : Parser, expr : Expr, errors : Array[ParseError]) -> AstBound {
  match eval_expr_in(expr, { vars: Map([]), fields: p.field_env.val, }) {
    Ok(n) => { value: Some(n), expr, }
    // not an error yet: the referenced field may appear later
    Err(UnresolvedRef(_, _)) => { value: None, expr, }
    Err(err) => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: err.to_text(), line: l, col: c, })
      { value: None, expr, }
    }
  }
}

///|
/// Record a resolved numeric constraint so later fields can reference it
fn record_constraint(
  p : Parser,
  field : String,
  constraint : String,
  value : Double,
) -> Unit {
  let inner : Map[String, Double] = match p.field_env.val.get(field) {
    Some(m) => m
    None => Map([])
  }
  inner.set(constraint, value)
  p.field_env.val.set(field, inner)
}

///|
/// Parse a check/constraint inside brackets
fn dsl_parse_check(
  p : Parser,
  field : String,
) -> (AstCheck?, Array[ParseError]) {
  let errors = []
  let name = match advance(p) {
    Ident(s) => s
    _ => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: "expected constraint name", line: l, col: c, })
      return (None, errors)
    }
  }
  // Boolean constraints (no value)
  match name {
    "distinct" => return (Some(Distinct), errors)
    "unique" => return (Some(Unique), errors)
    _ => ()
  }
  // Value constraints
  match expect(p, Eq) {
    Some(e) => {
      errors.push(e)
      return (None, errors)
    }
    None => ()
  }
  match name {
    "least" | "most" | "over" | "under" | "step" | "shortest" | "longest" => {
      // value may be an expression: 2 * 10, min(1, 5), -1, a.least
      let (expr, expr_errors) = dsl_parse_expr(p)
      for e in expr_errors {
        errors.push(e)
      }
      match expr {
        Some(e) => {
          let bound = make_bound(p, e, errors)
          match bound.value {
            Some(n) => record_constraint(p, field, name, n)
            None => ()
          }
          match name {
            "least" => (Some(Least(bound)), errors)
            "most" => (Some(Most(bound)), errors)
            "over" => (Some(Over(bound)), errors)
            "under" => (Some(Under(bound)), errors)
            "step" => (Some(Step(bound)), errors)
            "shortest" => (Some(Shortest(bound)), errors)
            _ => (Some(Longest(bound)), errors)
          }
        }
        None => (None, errors)
      }
    }
    "pattern" | "format" =>
      match advance(p) {
        Str(s) =>
          match name {
            "pattern" => (Some(Pattern(s)), errors)
            _ => (Some(Format(s)), errors)
          }
        Ident(s) =>
          match name {
            "pattern" => (Some(Pattern(s)), errors)
            _ => (Some(Format(s)), errors)
          }
        _ => {
          let (l, c) = cur_pos(p)
          errors.push({ msg: "expected string value", line: l, col: c, })
          (None, errors)
        }
      }
    "options" => {
      // options = [a, b, c]
      match expect(p, LBracket) {
        Some(e) => {
          errors.push(e)
          return (None, errors)
        }
        None => ()
      }
      let values = []
      skip_newlines(p)
      while peek(p) != RBracket && peek(p) != Eof {
        match advance(p) {
          Str(s) => values.push(s)
          Ident(s) => values.push(s)
          Number(n) => values.push(n.to_string())
          _ => ()
        }
        skip_newlines(p)
        if peek(p) == Comma {
          advance(p) |> ignore
          skip_newlines(p)
        }
      }
      match expect(p, RBracket) {
        Some(e) => errors.push(e)
        None => ()
      }
      (Some(Options(values)), errors)
    }
    _ => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: "unknown constraint '\{name}'", line: l, col: c, })
      (None, errors)
    }
  }
}

///|
/// Parse a complete DSL source into model AST
/// grammar: model_def+
pub fn dsl_parse(
  src : String,
) -> (Array[AstModel], Array[LexError], Array[ParseError]) {
  let (lexemes, lex_errors) = lex(src)
  let p = { tokens: lexemes, pos: { val: 0, }, field_env: { val: Map([]), }, }
  let models = []
  let parse_errors = []
  skip_newlines(p)
  while peek(p) != Eof {
    match peek(p) {
      KwModel => {
        let (model, errs) = dsl_parse_model(p)
        for e in errs {
          parse_errors.push(e)
        }
        match model {
          Some(m) => models.push(m)
          None => ()
        }
      }
      _ => {
        let (l, c) = cur_pos(p)
        parse_errors.push({ msg: "expected 'model'", line: l, col: c, })
        // Skip to next line to recover
        while peek(p) != Newline && peek(p) != Eof {
          advance(p) |> ignore
        }
      }
    }
    skip_newlines(p)
  }
  // Settle constraint references now that every field is known. A reference
  // that cannot be settled is a semantic problem, reported by the semantic
  // checker rather than as a syntax error.
  resolve_all_bounds(models) |> ignore
  (models, lex_errors, parse_errors)
}
