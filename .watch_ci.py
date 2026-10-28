import json, re, time, urllib.request

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36"


def fetch(url, headers=None):
    h = {"User-Agent": UA}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=45) as r:
        return r.read().decode("utf-8", errors="replace")


# 1. find the newest Kernel tests run from the branch
page = fetch("https://github.com/Tino-hue/projdesk/actions/workflows/kernel.yml")
runs = sorted(set(re.findall(r"/Tino-hue/projdesk/actions/runs/(\d+)", page)), key=int)
print("runs seen:", runs[-5:])
if not runs:
    raise SystemExit(0)

rid = runs[-1]
print("watching run", rid)
for _ in range(30):
    rp = fetch("https://github.com/Tino-hue/projdesk/actions/runs/%s" % rid)
    m = re.search(r'"conclusion":"(success|failure|cancelled|skipped)"', rp)
    status = re.search(r'"status":"(completed|in_progress|queued|waiting)"', rp)
    print("   status=%s conclusion=%s" % (status.group(1) if status else "?", m.group(1) if m else "-"))
    if m:
        break
    time.sleep(20)

print()
print("=== job ids ===")
rp = fetch("https://github.com/Tino-hue/projdesk/actions/runs/%s" % rid)
jobs = sorted(set(re.findall(r"/Tino-hue/projdesk/actions/runs/%s/job/(\d+)" % rid, rp)))
print(jobs)
for j in jobs:
    print()
    print("--- job %s ---" % j)
    try:
        log = fetch("https://github.com/Tino-hue/projdesk/actions/runs/%s/job/%s" % (rid, j))
        # the log lines are embedded in the page payload
        lines = re.findall(r'\[(\d{4}-\d\d-\d\dT[\d:.]+Z)\][^\n]{0,400}', log)
        for l in lines[-60:]:
            print("   " + l[:200])
        if not lines:
            for m2 in re.findall(r'"message":"([^"]{5,300})"', log)[:15]:
                print("   msg:", m2[:220])
            for m3 in re.findall(r'"stepName":"([^"]+)"', log)[:15]:
                print("   step:", m3)
    except Exception as e:
        print("   failed:", e)
