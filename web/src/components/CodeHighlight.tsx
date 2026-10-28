// Lightweight syntax highlighter for JSON / SQL / GraphQL
// Renders <span> tokens with color classes — no external deps

type Token = { type: string; text: string };

function tokenizeJson(src: string): Token[] {
  const tokens: Token[] = [];
  const re = /("(?:[^"\\]|\\.)*")\s*:?|\b(true|false|null)\b|\b(-?\d+(?:\.\d+)?)\b|([{}[\],:])|(\s+)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(src))) {
    if (m.index > last) tokens.push({ type: 'plain', text: src.slice(last, m.index) });
    if (m[1]) {
      const isKey = src[m.index + m[1].length] === ':';
      tokens.push({ type: isKey ? 'key' : 'string', text: m[1] });
    } else if (m[2]) tokens.push({ type: 'keyword', text: m[2] });
    else if (m[3]) tokens.push({ type: 'number', text: m[3] });
    else if (m[4]) tokens.push({ type: 'punct', text: m[4] });
    else tokens.push({ type: 'plain', text: m[0] });
    last = m.index + m[0].length;
  }
  if (last < src.length) tokens.push({ type: 'plain', text: src.slice(last) });
  return tokens;
}

function tokenizeSql(src: string): Token[] {
  const tokens: Token[] = [];
  const re = /(--[^\n]*)|('(?:[^']|'')*')|\b(CREATE|TABLE|PRIMARY|KEY|NOT|NULL|UNIQUE|DEFAULT|CHECK|IN|AND|OR|SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|TEXT|INTEGER|BIGINT|BOOLEAN|REAL|DOUBLE|PRECISION|BLOB|TIMESTAMPTZ|DATETIME|TINYINT|BYTEA|IF|EXISTS|CASCADE|REFERENCES|ALTER|ADD|COLUMN|CONSTRAINT)\b|\b(\d+(?:\.\d+)?)\b|([(),;])|(\s+)/gi;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(src))) {
    if (m.index > last) tokens.push({ type: 'plain', text: src.slice(last, m.index) });
    if (m[1]) tokens.push({ type: 'comment', text: m[1] });
    else if (m[2]) tokens.push({ type: 'string', text: m[2] });
    else if (m[3]) tokens.push({ type: 'keyword', text: m[3] });
    else if (m[4]) tokens.push({ type: 'number', text: m[4] });
    else if (m[5]) tokens.push({ type: 'punct', text: m[5] });
    else tokens.push({ type: 'plain', text: m[0] });
    last = m.index + m[0].length;
  }
  if (last < src.length) tokens.push({ type: 'plain', text: src.slice(last) });
  return tokens;
}

function tokenizeGraphql(src: string): Token[] {
  const tokens: Token[] = [];
  const re = /("""[\s\S]*?""")|("(?:[^"\\]|\\.)*")|\b(type|input|scalar|enum|interface|union|schema|query|mutation|subscription|extend|implements|on|fragment|directive|repeatable|true|false|null)\b|([A-Z][A-Za-z0-9_]*)|([{}()\[\]:!=,@|&])|(\s+)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(src))) {
    if (m.index > last) tokens.push({ type: 'plain', text: src.slice(last, m.index) });
    if (m[1]) tokens.push({ type: 'comment', text: m[1] });
    else if (m[2]) tokens.push({ type: 'string', text: m[2] });
    else if (m[3]) tokens.push({ type: 'keyword', text: m[3] });
    else if (m[4]) tokens.push({ type: 'type', text: m[4] });
    else if (m[5]) tokens.push({ type: 'punct', text: m[5] });
    else tokens.push({ type: 'plain', text: m[0] });
    last = m.index + m[0].length;
  }
  if (last < src.length) tokens.push({ type: 'plain', text: src.slice(last) });
  return tokens;
}

const TOKEN_COLORS: Record<string, string> = {
  key: 'text-sky-300',
  string: 'text-emerald-300',
  number: 'text-amber-300',
  keyword: 'text-violet-300',
  type: 'text-sky-300',
  comment: 'text-slate-500',
  punct: 'text-slate-400',
  plain: 'text-slate-200',
};

export function highlightLine(line: string, lang: string): React.ReactElement[] {
  let tokens: Token[];
  if (lang === 'sql') tokens = tokenizeSql(line);
  else if (lang === 'graphql') tokens = tokenizeGraphql(line);
  else tokens = tokenizeJson(line);
  return tokens.map((t, i) => (
    <span key={i} className={TOKEN_COLORS[t.type] || 'text-slate-200'}>
      {t.text}
    </span>
  ));
}

/** Render full source with syntax highlighting and optional changed-line marker */
export function HighlightedCode({ code, lang, changedLines }: { code: string; lang: string; changedLines?: Set<number> }) {
  const lines = code.split('\n');
  return (
    <div className="code-block max-h-[360px]">
      {lines.map((line, i) => {
        const isChanged = changedLines?.has(i);
        return (
          <div
            key={i}
            className={isChanged ? 'line-changed' : ''}
          >
            {line.length === 0 ? ' ' : highlightLine(line, lang)}
          </div>
        );
      })}
    </div>
  );
}

/** Compute changed line numbers between two code strings */
export function diffLines(oldCode: string, newCode: string): Set<number> {
  const changed = new Set<number>();
  const oldLines = oldCode.split('\n');
  const newLines = newCode.split('\n');
  for (let i = 0; i < newLines.length; i++) {
    if (oldLines[i] !== newLines[i]) changed.add(i);
  }
  return changed;
}

