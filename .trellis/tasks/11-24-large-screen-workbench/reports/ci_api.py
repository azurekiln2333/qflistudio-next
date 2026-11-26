"""Bounded GitHub Actions evidence and failed-job retry for this task."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import urllib.request
import urllib.parse


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected and urllib.parse.urlsplit(req.full_url).netloc != urllib.parse.urlsplit(newurl).netloc:
            redirected.remove_header("Authorization")
        return redirected


def request(path, method="GET", data=None, raw=False):
    result = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n", text=True,
        capture_output=True, timeout=20,
        env=dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never"),
    )
    credential = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    headers = {"User-Agent": "qfli-workbench-ci", "Accept": "application/vnd.github+json"}
    if credential.get("password"):
        headers["Authorization"] = "Bearer " + credential["password"]
    payload = None if data is None else json.dumps(data).encode("utf-8")
    if payload is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request("https://api.github.com/" + path, data=payload, headers=headers, method=method)
    with urllib.request.build_opener(SafeRedirect()).open(req, timeout=40) as response:
        body = response.read()
        if raw:
            return body
        return json.loads(body) if body else {"http_status": response.status}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", choices=["qflistudio-core", "qflistudio-next"])
    parser.add_argument("run", type=int)
    parser.add_argument("--retry-failed", action="store_true")
    args = parser.parse_args()
    base = f"repos/azurekiln2333/{args.repo}/actions/runs/{args.run}"
    run = request(base)
    jobs = request(base + "/jobs?per_page=100")["jobs"]
    record = {"observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "run": run, "jobs": jobs}
    if args.retry_failed:
        if run["status"] != "completed" or run["conclusion"] not in ("failure", "timed_out"):
            raise SystemExit("Run is not a completed failed run; no retry submitted.")
        record["retry"] = request(base + "/rerun-failed-jobs", "POST")
    output = Path(__file__).parent / f"ci-{args.repo}-{args.run}-attempt-{run['run_attempt']}.json"
    output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{run['head_sha']} {run['status']} / {run['conclusion']} attempt {run['run_attempt']}")
    for job in jobs:
        print(f"  {job['name']}: {job['conclusion'] or job['status']}")
    if "retry" in record:
        print("Failed jobs retry accepted:", record["retry"])
    print("Evidence:", output.name)


if __name__ == "__main__":
    main()
