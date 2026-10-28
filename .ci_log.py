import json, time, urllib.request

H = {"User-Agent": "projdesk-check", "Accept": "application/vnd.github+json"}


def get(url, raw=False):
    req = urllib.request.Request(url, headers=H)
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
    return data if raw else json.loads(data.decode("utf-8"))


runs = get("https://api.github.com/repos/Tino-hue/projdesk/actions/runs?per_page=10")["workflow_runs"]
kernel = [r for r in runs if r["name"] == "Kernel tests"]
if not kernel:
    print("no Kernel tests run found; recent runs:")
    for r in runs:
        print("  ", r["name"], r["status"], r["conclusion"], r["head_branch"])
    raise SystemExit(0)

run = kernel[0]
print("run id:", run["id"], "event:", run["event"], "branch:", run["head_branch"])
print("status:", run["status"], "conclusion:", run["conclusion"])
print("url:", run["html_url"])
print()

jobs = get("https://api.github.com/repos/Tino-hue/projdesk/actions/runs/%s/jobs" % run["id"])["jobs"]
for job in jobs:
    print("JOB:", job["name"], "->", job["conclusion"])
    for s in job.get("steps") or []:
        print("   [%s] %-42s %s" % (s["number"], s["name"], s["conclusion"]))
    print()

print("=== job log (last 120 lines) ===")
try:
    log = get("https://api.github.com/repos/Tino-hue/projdesk/actions/jobs/%s/logs" % jobs[0]["id"], raw=True).decode("utf-8", errors="replace")
    lines = [l for l in log.splitlines() if l.strip()]
    for l in lines[-120:]:
        print(l[:200])
except Exception as e:
    print("could not fetch the job log:", e)
