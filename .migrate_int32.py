"""Rename the 32-bit integer type to its canonical name, in code positions only.

The toolchain renamed the type to `Int32` and kept `Int` as an alias for it.
The kernel's own source should use the canonical name, like the dependency it
is written against does.

Three things must not change:

  - the DSL's type vocabulary: the string "Int" inside a model source is the
    DSL's own type name
  - constructor patterns: `Int` is still the constructor to match on
  - constructor values: `Int` is still the constructor to pass around
"""
import glob
import re

TOKEN = re.compile(r'(?<![A-Za-z0-9_])Int(?![A-Za-z0-9_])')


def split_strings(text):
    out = []
    i = 0
    n = len(text)
    start = 0
    in_string = False
    while i < n:
        c = text[i]
        if c == '"':
            out.append((text[start:i], not in_string))
            in_string = not in_string
            start = i
            i += 1
            continue
        if c == "\\" and in_string and i + 1 < n:
            i += 2
            continue
        i += 1
    out.append((text[start:], not in_string))
    return out


def is_type_position(segment, at):
    """True when the token names a type rather than a constructor."""
    before = segment[:at].rstrip()
    after = segment[at + 3:]
    if before.endswith(":"):
        return True
    if after.startswith("]") or after.startswith("?") or after.startswith("->"):
        return True
    return False


def migrate(path):
    text = open(path, encoding="utf-8").read()
    pieces = []
    changed = 0
    for segment, is_code in split_strings(text):
        if not is_code:
            pieces.append(segment)
            continue
        out = []
        pos = 0
        for m in TOKEN.finditer(segment):
            out.append(segment[pos:m.start()])
            if is_type_position(segment, m.start()):
                out.append("Int32")
                changed += 1
            else:
                out.append("Int")
            pos = m.end()
        out.append(segment[pos:])
        pieces.append("".join(out))
    result = "".join(pieces)
    if result != text:
        open(path, "w", encoding="utf-8", newline="").write(result)
    return changed


total = 0
for f in sorted(glob.glob("moonbit/main/*.mbt") + glob.glob("moonbit/jsonparse/*.mbt")):
    n = migrate(f)
    if n:
        print("  %-30s %d" % (f, n))
        total += n
print("renamed", total, "type positions")
