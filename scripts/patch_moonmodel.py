#!/usr/bin/env python3
"""Make the published moonmodel package compile against this kernel's toolchain.

The MoonBit toolchain this kernel is written for spells the 32-bit integer
`Int`. MoonBit later renamed that type to `Int32`, and the moonmodel package
is published against the newer spelling, so the dependency has to be adjusted
before it will compile.

The patch is deliberately minimal: it renames the type in type positions and
leaves everything else alone. It is applied to the copy of the package that
the build downloaded, never to the registry cache.

If the dependency has not been fetched yet, this fetches it first, so it can
be run on a fresh clone without any other step.

This is the portable counterpart of scripts/patch_moonmodel.ps1; the two
apply the same change and are kept in step with each other.

Usage:
    python3 scripts/patch_moonmodel.py [path-to-moonmodel]
"""

import os
import re
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULE_DIR = os.path.join(REPO_ROOT, "moonbit")
DEFAULT_PATH = os.path.join(MODULE_DIR, ".mooncakes", "moonbitstack", "moonmodel")

# The type name only: a quoted "Int32" is a JSON format value, not a type.
TYPE_NAME = re.compile(r'(?<![a-zA-Z"\'])\bInt32\b(?![a-zA-Z"\'])')


def dependency_files(path):
    if not os.path.isdir(path):
        return []
    found = []
    for root, _dirs, files in os.walk(path):
        for name in files:
            if name.endswith(".mbt"):
                found.append(os.path.join(root, name))
    return sorted(found)


def fetch(path):
    """Fetch the dependency without compiling it."""
    for command in (["moon", "install"], ["moon", "build", "--target", "wasm-gc"]):
        if not shutil_which(command[0]):
            continue
        print("Fetching the moonmodel dependency with `{}`...".format(" ".join(command)))
        # The toolchain writes progress to stderr and exits non-zero when the
        # dependency still needs patching; both are expected here.
        result = subprocess.run(command, cwd=MODULE_DIR, capture_output=True, text=True)
        if dependency_files(path):
            return True
        del result
    return False


def shutil_which(name):
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        candidate = os.path.join(directory, name + (".exe" if os.name == "nt" else ""))
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PATH
    files = dependency_files(path)
    if not files:
        fetch(path)
        files = dependency_files(path)
    if not files:
        print("moonmodel not found at {}".format(path), file=sys.stderr)
        print("Run 'cd moonbit && moon build' to fetch it, then run this again.", file=sys.stderr)
        return 1

    patched = 0
    for file in files:
        with open(file, "r", encoding="utf-8") as handle:
            content = handle.read()
        updated = TYPE_NAME.sub("Int", content)
        if updated != content:
            with open(file, "w", encoding="utf-8", newline="") as handle:
                handle.write(updated)
            patched += 1

    # The JSON Schema format value for a 32-bit integer stays "int32".
    json_file = os.path.join(path, "json", "json.mbt")
    if os.path.isfile(json_file):
        with open(json_file, "r", encoding="utf-8") as handle:
            content = handle.read()
        updated = content.replace('Json::string("Int")', 'Json::string("int32")')
        if updated != content:
            with open(json_file, "w", encoding="utf-8", newline="") as handle:
                handle.write(updated)

    if patched:
        print("Patched {} moonmodel file(s) for this toolchain".format(patched))
    else:
        print("moonmodel already matches this toolchain - nothing to patch")
    return 0


if __name__ == "__main__":
    sys.exit(main())
