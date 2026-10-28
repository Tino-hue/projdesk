import json, re, urllib.request

H = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36"}


def fetch(url):
    req = urllib.request.Request(url, headers=H)
    with urllib.request.urlopen(req, timeout=40) as r:
        return r.read().decode("utf-8", errors="replace")


page = fetch("https://github.com/Tino-hue/projdesk/actions/workflows/kernel.yml")
runs = sorted(set(re.findall(r"/Tino-hue/projdesk/actions/runs/(\d+)", page)), key=int)
print("runs found:", runs[-4:] if runs else "none")

if not runs:
    print(page[:800])
    raise SystemExit(0)

for rid in runs[-2:]:
    print()
    print("=" * 70)
    print("RUN", rid)
    print("=" * 70)
    rp = fetch("https://github.com/Tino-hue/projdesk/actions/runs/%s" % rid)
    # GitHub embeds the step data and the log lines in the page payload
    for pat in [r'"(Install the MoonBit toolchain|Fetch the moonmodel dependency|Patch moonmodel[^"]*|moon check|moon test)"',
                r'"(conclusion|status)":"(failure|completed)"']:
        for m in sorted(set(re.findall(pat, rp)))[:10]:
            print("   ", m if isinstance(m, str) else m)
    # the error annotation usually shows up as text
    for m in re.findall(r'"message":"([^"]{10,300})"', rp)[:20]:
        print("   msg:", m[:220])
    for m in re.findall(r"(?:Error|error):[^\"<]{5,200}", rp)[:15]:
        print("   err:", m[:220])
