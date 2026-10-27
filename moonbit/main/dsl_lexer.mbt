// DSL Lexer: source text -> Token stream
// Hand-written scanner for ProjDesk modeling language

///|
/// Token types for the DSL
pub(all) enum Token {
  Ident(String)
  Number(Double)
  Str(String)
  // Keywords
  KwModel
  KwRef
  KwList
  KwDict
  KwNest
  // Symbols
  Colon
  Comma
  LBracket
  RBracket
  LBrace
  RBrace
  LParen
  RParen
  At
  Eq
  Arrow
  // Special
  Newline
  Comment(String)
  Eof
} derive(Eq, Debug)

///|
pub extend Lexeme with Eq::{equal, not_equal}

///|
pub extend Lexeme with Debug::{to_repr}

///|
pub extend LexError with Eq::{equal, not_equal}

///|
pub extend LexError with Debug::{to_repr}

///|
pub extend Token with Eq::{equal, not_equal}

///|
pub extend Token with Debug::{to_repr}


///|

///|
/// A positioned token for error reporting
pub(all) struct Lexeme {
  token : Token
  line : Int
  col : Int
} derive(Eq, Debug)

///|

///|
/// Lexer state
pub(all) struct Lexer {
  src : String
  pos : Ref[Int]
  line : Ref[Int]
  col : Ref[Int]
}

///|
/// Lexer error with position
pub(all) enum LexError {
  UnexpectedChar(Char, Int, Int)
  UnterminatedString(Int, Int)
  InvalidNumber(String, Int, Int)
} derive(Eq, Debug)

///|

///|
pub fn LexError::to_text(self : LexError) -> String {
  match self {
    UnexpectedChar(c, l, col) => "line \{l}:\{col}: unexpected character '\{c}'"
    UnterminatedString(l, col) => "line \{l}:\{col}: unterminated string"
    InvalidNumber(s, l, col) => "line \{l}:\{col}: invalid number '\{s}'"
  }
}

///|
/// Check if character is a letter or underscore
fn is_ident_start(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 97 && code <= 122) || (code >= 65 && code <= 90) || code == 95
}

///|
/// Check if character is a letter, digit, or underscore
fn is_ident_cont(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 97 && code <= 122) ||
  (code >= 65 && code <= 90) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
/// Check if character is a digit
fn is_digit(c : Char) -> Bool {
  let code = c.to_int()
  code >= 48 && code <= 57
}

///|
/// Check if character is whitespace (not newline)
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r'
}

///|
/// Lookup keyword from identifier text
fn keyword_of(s : String) -> Token {
  match s {
    "model" => KwModel
    "Ref" => KwRef
    "List" => KwList
    "Dict" => KwDict
    "Nest" => KwNest
    _ => Ident(s)
  }
}

///|
/// Tokenize source string into Lexeme array
pub fn lex(src : String) -> (Array[Lexeme], Array[LexError]) {
  let lexer = { src, pos: { val: 0, }, line: { val: 1, }, col: { val: 1, }, }
  let tokens : Array[Lexeme] = []
  let errors : Array[LexError] = []

  while lexer.pos.val < lexer.src.length() {
    let c = lexer.src[lexer.pos.val].unsafe_to_char()
    if c == '\n' {
      tokens.push({ token: Newline, line: lexer.line.val, col: lexer.col.val, })
      lexer.line.val = lexer.line.val + 1
      lexer.col.val = 1
      lexer.pos.val = lexer.pos.val + 1
    } else if is_space(c) {
      lexer.col.val = lexer.col.val + 1
      lexer.pos.val = lexer.pos.val + 1
    } else if is_ident_start(c) {
      let start = lexer.pos.val
      let start_col = lexer.col.val
      while lexer.pos.val < lexer.src.length() &&
            is_ident_cont(lexer.src[lexer.pos.val].unsafe_to_char()) {
        lexer.pos.val = lexer.pos.val + 1
        lexer.col.val = lexer.col.val + 1
      }
      let text = lexer.src[start:lexer.pos.val].to_owned()
      tokens.push({
        token: keyword_of(text),
        line: lexer.line.val,
        col: start_col,
      })
    } else if is_digit(c) {
      let start = lexer.pos.val
      let start_col = lexer.col.val
      while lexer.pos.val < lexer.src.length() &&
            is_digit(lexer.src[lexer.pos.val].unsafe_to_char()) {
        lexer.pos.val = lexer.pos.val + 1
        lexer.col.val = lexer.col.val + 1
      }
      // Handle decimal point
      if lexer.pos.val + 1 < lexer.src.length() &&
        lexer.src[lexer.pos.val].unsafe_to_char() == '.' &&
        is_digit(lexer.src[lexer.pos.val + 1].unsafe_to_char()) {
        lexer.pos.val = lexer.pos.val + 1
        lexer.col.val = lexer.col.val + 1
        while lexer.pos.val < lexer.src.length() &&
              is_digit(lexer.src[lexer.pos.val].unsafe_to_char()) {
          lexer.pos.val = lexer.pos.val + 1
          lexer.col.val = lexer.col.val + 1
        }
      }
      let text = lexer.src[start:lexer.pos.val].to_owned()
      match parse_number(text) {
        Some(n) =>
          tokens.push({
            token: Number(n),
            line: lexer.line.val,
            col: start_col,
          })
        None => errors.push(InvalidNumber(text, lexer.line.val, start_col))
      }
    } else if c == '/' &&
      lexer.pos.val + 1 < lexer.src.length() &&
      lexer.src[lexer.pos.val + 1].unsafe_to_char() == '/' {
      // Line comment: skip to end of line, emit as Comment token
      let start_col = lexer.col.val
      lexer.pos.val = lexer.pos.val + 2
      lexer.col.val = lexer.col.val + 2
      let comment_start = lexer.pos.val
      while lexer.pos.val < lexer.src.length() &&
            lexer.src[lexer.pos.val].unsafe_to_char() != '\n' {
        lexer.pos.val = lexer.pos.val + 1
        lexer.col.val = lexer.col.val + 1
      }
      let text = lexer.src[comment_start:lexer.pos.val].to_owned()
      tokens.push({
        token: Comment(text),
        line: lexer.line.val,
        col: start_col,
      })
    } else if c == '"' {
      let start_col = lexer.col.val
      lexer.pos.val = lexer.pos.val + 1
      lexer.col.val = lexer.col.val + 1
      let str_start = lexer.pos.val
      let mut terminated = false
      while lexer.pos.val < lexer.src.length() {
        let sc = lexer.src[lexer.pos.val].unsafe_to_char()
        if sc == '"' {
          terminated = true
          break
        }
        if sc == '\n' {
          break
        }
        lexer.pos.val = lexer.pos.val + 1
        lexer.col.val = lexer.col.val + 1
      }
      if terminated {
        let text = lexer.src[str_start:lexer.pos.val].to_owned()
        tokens.push({ token: Str(text), line: lexer.line.val, col: start_col, })
        lexer.pos.val = lexer.pos.val + 1
        lexer.col.val = lexer.col.val + 1
      } else {
        errors.push(UnterminatedString(lexer.line.val, start_col))
      }
    } else {
      let tok = match c {
        ':' => Colon
        ',' => Comma
        '[' => LBracket
        ']' => RBracket
        '{' => LBrace
        '}' => RBrace
        '(' => LParen
        ')' => RParen
        '@' => At
        '=' => Eq
        _ => {
          errors.push(UnexpectedChar(c, lexer.line.val, lexer.col.val))
          Eof // placeholder, will not be pushed
        }
      }
      if tok != Eof {
        tokens.push({ token: tok, line: lexer.line.val, col: lexer.col.val, })
      }
      lexer.pos.val = lexer.pos.val + 1
      lexer.col.val = lexer.col.val + 1
    }
  }
  tokens.push({ token: Eof, line: lexer.line.val, col: lexer.col.val, })
  (tokens, errors)
}

///|
/// Parse a number string
fn parse_number(s : String) -> Double? {
  // Simple manual parse: integer or decimal
  let mut result = 0.0
  let mut frac = 0.0
  let mut divisor = 1.0
  let mut in_frac = false
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].unsafe_to_char()
    if c == '.' {
      in_frac = true
    } else if is_digit(c) {
      let digit = (c.to_int() - 48).to_double()
      if in_frac {
        divisor = divisor * 10.0
        frac = frac + digit / divisor
      } else {
        result = result * 10.0 + digit
      }
    } else {
      return None
    }
  }
  Some(result + frac)
}

///|
/// Convert token to display text (for error messages)
pub fn Token::to_text(self : Token) -> String {
  match self {
    Ident(s) => s
    Number(n) => n.to_string()
    Str(s) => "\"" + s + "\""
    KwModel => "model"
    KwRef => "Ref"
    KwList => "List"
    KwDict => "Dict"
    KwNest => "Nest"
    Colon => ":"
    Comma => ","
    LBracket => "["
    RBracket => "]"
    LBrace => "{"
    RBrace => "}"
    LParen => "("
    RParen => ")"
    At => "@"
    Eq => "="
    Arrow => "->"
    Newline => "newline"
    Comment(s) => "// " + s
    Eof => "end of input"
  }
}
