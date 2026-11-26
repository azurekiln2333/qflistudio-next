"""Fetch completed failed-job logs using the existing GitHub credential."""

import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request

class PublicRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, url):
        redirected = super().redirect_request(request, fp, code, msg, headers, url)
        if redirected is not None:
            redirected.remove_header("Authorization")
        return redirected

opener = urllib.request.build_opener(PublicRedirect())
sys.stdout.reconfigure(encoding="utf-8")
record = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never")
result = subprocess.run(
    ["git", "credential", "fill"],
    input=f"protocol=https\nhost=github.com\npath=azurekiln2333/{record['repo']}.git\n\n",
    text=True, capture_output=True, env=env, timeout=30,
)
credential = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
if not credential.get("password"):
    raise SystemExit("No stored GitHub credential for log access")
for job in record["jobs"]:
    selected = sys.argv[sys.argv.index("--job") + 1] if "--job" in sys.argv else None
    if selected and job["name"] != selected:
        continue
    if job["conclusion"] not in ("failure", "timed_out") and "--running" not in sys.argv and not selected:
        continue
    url = f"https://api.github.com/repos/azurekiln2333/{record['repo']}/actions/jobs/{job['id']}/logs"
    request = urllib.request.Request(url, headers={
        "User-Agent": "qfli-mobile-integration-review",
        "Authorization": "Bearer " + credential["password"],
    })
    for attempt in range(3):
        try:
            with opener.open(request, timeout=20) as response:
                log = response.read().decode("utf-8", errors="replace")
            break
        except OSError as error:
            if attempt == 2:
                raise SystemExit(f"Could not download job {job['id']} logs: {type(error).__name__}, HTTP {getattr(error, 'code', 'unavailable')}")
    output = Path(__file__).parent / f"takeover-log-{record['run_id']}-{job['id']}.txt"
    output.write_text(log, encoding="utf-8")
    print(f"{job['name']}: {output}")
    lines = log.splitlines()
    if job["status"] == "in_progress" or selected:
        print("\n".join(lines[-12:]))
    for index, line in enumerate(lines):
        if any(marker in line for marker in ("not ok", "AssertionError", "error TS", "error:", "FAILURE:", "ArkTS:")):
            print("\n".join(lines[max(0,index-2):index+16]))
