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
/// AST constraint representation
pub(all) enum AstCheck {
  Least(Double)
  Most(Double)
  Over(Double)
  Under(Double)
  Step(Double)
  Shortest(Int)
  Longest(Int)
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
  line : Int
  col : Int
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
  pos : Ref[Int]
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
fn cur_pos(p : Parser) -> (Int, Int) {
  if p.pos.val < p.tokens.length() {
    (p.tokens[p.pos.val].line, p.tokens[p.pos.val].col)
  } else {
    (0, 0)
  }
}

///|
/// Skip newlines
fn skip_newlines(p : Parser) -> Unit {
  while peek(p) == Newline {
    advance(p) |> ignore
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
      errors.push({ msg: "expected model name", line: l, col: c })
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
    (Some({ name, fields, doc: "" }), errors)
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
      errors.push({ msg: "expected field name", line: l, col: c })
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
          Ident(s) => {
            match s {
              "optional" => required = false
              "nullable" => nullable = true
              "unique" => checks.push(Unique)
              "distinct" => checks.push(Distinct)
              _ => attrs.push(s)
            }
          }
          _ => {
            let (l, c) = cur_pos(p)
            errors.push({ msg: "expected attribute name after @", line: l, col: c })
          }
        }
      }
      LBracket => {
        advance(p) |> ignore
        skip_newlines(p)
        while peek(p) != RBracket && peek(p) != Eof {
          let (check, check_errors) = dsl_parse_check(p)
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
    (Some({ name, kind, required, nullable, doc: "", checks, attrs }), errors)
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
          errors.push({ msg: "expected model name in Ref()", line: l, col: c })
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
    Ident(s) => (Named(s), errors)
    _ => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: "expected type name", line: l, col: c })
      (Named("Text"), errors)
    }
  }
}

///|
/// Parse a check/constraint inside brackets
fn dsl_parse_check(p : Parser) -> (AstCheck?, Array[ParseError]) {
  let errors = []
  let name = match advance(p) {
    Ident(s) => s
    _ => {
      let (l, c) = cur_pos(p)
      errors.push({ msg: "expected constraint name", line: l, col: c })
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
    "least" | "most" | "over" | "under" | "step" => {
      match advance(p) {
        Number(n) =>
          match name {
            "least" => (Some(Least(n)), errors)
            "most" => (Some(Most(n)), errors)
            "over" => (Some(Over(n)), errors)
            "under" => (Some(Under(n)), errors)
            _ => (Some(Step(n)), errors)
          }
        _ => {
          let (l, c) = cur_pos(p)
          errors.push({ msg: "expected number", line: l, col: c })
          (None, errors)
        }
      }
    }
    "shortest" | "longest" => {
      match advance(p) {
        Number(n) => {
          let int_val = n.to_int()
          match name {
            "shortest" => (Some(Shortest(int_val)), errors)
            _ => (Some(Longest(int_val)), errors)
          }
        }
        _ => {
          let (l, c) = cur_pos(p)
          errors.push({ msg: "expected integer", line: l, col: c })
          (None, errors)
        }
      }
    }
    "pattern" | "format" => {
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
          errors.push({ msg: "expected string value", line: l, col: c })
          (None, errors)
        }
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
      errors.push({ msg: "unknown constraint '\{name}'", line: l, col: c })
      (None, errors)
    }
  }
}

///|
/// Parse a complete DSL source into model AST
/// grammar: model_def+
pub fn dsl_parse(src : String) -> (Array[AstModel], Array[LexError], Array[ParseError]) {
  let (lexemes, lex_errors) = lex(src)
  let p = { tokens: lexemes, pos: { val: 0 } }
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
        parse_errors.push({ msg: "expected 'model'", line: l, col: c })
        // Skip to next line to recover
        while peek(p) != Newline && peek(p) != Eof {
          advance(p) |> ignore
        }
      }
    }
    skip_newlines(p)
  }
  (models, lex_errors, parse_errors)
}
