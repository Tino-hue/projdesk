import base64, json, re, time, urllib.request

H = {"User-Agent": "projdesk-check"}


def api_json(url):
    last = None
    for _ in range(5):
        try:
            req = urllib.request.Request(url, headers=H)
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:
            last = e
            time.sleep(2)
    raise last


def api_file(repo, path, ref="main"):
    data = api_json("https://api.github.com/repos/%s/contents/%s?ref=%s" % (repo, path, ref))
    return base64.b64decode(data["content"]).decode("utf-8", errors="replace")


tree = api_json("https://api.github.com/repos/moonbitlang/moon/git/trees/main?recursive=1")["tree"]
rs = [t["path"] for t in tree if t["path"].endswith(".rs")]

print("=== files mentioning a toolchain version key in the module file ===")
hits = []
for p in rs:
    if not re.search(r"mod|module|manifest|project", p, re.I):
        continue
    try:
        src = api_file("moonbitlang/moon", p)
    except Exception:
        continue
    if re.search(r'"toolchain"', src):
        hits.append(p)
        for i, line in enumerate(src.splitlines(), 1):
            if re.search(r'"toolchain"|toolchain_version|toolchain\b', line, re.I):
                print("  %s:%d  %s" % (p, i, line.strip()[:160]))
print("  files:", hits[:12])

print()
print("=== upgrade.rs: how the toolchain archive is downloaded ===")
try:
    src = api_file("moonbitlang/moon", "crates/moonbuild/src/upgrade.rs")
    for i, line in enumerate(src.splitlines(), 1):
        if re.search(r"format!\(|download|moonrun|moonc|extract|tar|zip|install/unix", line, re.I):
            print("  %4d  %s" % (i, line.strip()[:180]))
except Exception as e:
    print("  failed:", e)
