"""Record public GitHub CI evidence for an exact commit; never mutate a run."""

import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")

def headers():
    result = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n", text=True,
        capture_output=True, timeout=20,
        env=dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never"),
    )
    credential = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    value = {"User-Agent": "qfli-mobile-integration-review"}
    if credential.get("password"):
        value["Authorization"] = "Bearer " + credential["password"]
    return value

HEADERS = headers()

def get(path):
    request = urllib.request.Request(
        "https://api.github.com/" + path,
        headers=HEADERS,
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


parser = argparse.ArgumentParser()
parser.add_argument("repo", choices=["qflistudio-core", "qflistudio-next"])
parser.add_argument("sha")
parser.add_argument("--branch", default="ci/mobile-files")
args = parser.parse_args()
workflow = "core-check" if args.repo == "qflistudio-core" else "App installers"
base = f"repos/azurekiln2333/{args.repo}"
query = urllib.parse.urlencode(
    {"head_sha": args.sha, "branch": args.branch, "per_page": 20}
)
runs = get(f"{base}/actions/runs?{query}")["workflow_runs"]
matches = [
    run for run in runs
    if run["head_sha"] == args.sha and run["name"] == workflow
]
if not matches:
    print(f"No {workflow} run for {args.sha} on {args.branch}")
    raise SystemExit(0)
run = max(matches, key=lambda item: (item["run_number"], item["run_attempt"]))
jobs = get(f"{base}/actions/runs/{run['id']}/jobs?per_page=100")["jobs"]
record = {
    "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "repo": args.repo,
    "workflow": workflow,
    "branch": args.branch,
    "sha": args.sha,
    "run_id": run["id"],
    "run_attempt": run["run_attempt"],
    "status": run["status"],
    "conclusion": run["conclusion"],
    "url": run["html_url"],
    "jobs": jobs,
}
print(f"{workflow} {args.sha[:12]} run {run['id']}: {run['status']} / {run['conclusion']}")
for job in jobs:
    active = [step["name"] for step in job["steps"] if step["status"] == "in_progress"]
    print(f"  {job['name']}: {job['conclusion'] or job['status']}" + (f" ({active[0]})" if active else ""))
    if job["conclusion"] in ("failure", "timed_out"):
        failed_steps = [step["name"] for step in job["steps"] if step["conclusion"] == "failure"]
        print("    Failed steps: " + ", ".join(failed_steps))
        check = job["check_run_url"].removeprefix("https://api.github.com/")
        annotations = get(check + "/annotations?per_page=100")
        job["failure_annotations"] = annotations
        for annotation in annotations:
            if annotation["annotation_level"] == "failure":
                print("    " + annotation.get("title", "") + ": " + annotation["message"])
output = Path(__file__).parent / f"takeover-ci-{args.repo}-{args.sha[:12]}-{run['id']}.json"
output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Evidence: {output.name}")
