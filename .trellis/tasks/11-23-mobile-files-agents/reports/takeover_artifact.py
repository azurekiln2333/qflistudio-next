"""Fetch one old run artifact zip using the existing GitHub credential.

Reuses the credential lookup and redirect hygiene of takeover_logs.py:
`git credential fill` for the token, and Authorization stripped on any
external redirect so the signed storage URL is never sent the token.
Writes only into this reports directory. Prints no credential material.
"""

import io
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request
import zipfile

class PublicRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, url):
        redirected = super().redirect_request(request, fp, code, msg, headers, url)
        if redirected is not None:
            redirected.remove_header("Authorization")
        return redirected

opener = urllib.request.build_opener(PublicRedirect())
sys.stdout.reconfigure(encoding="utf-8")

here = Path(__file__).parent
record = json.loads(
    (here / "takeover-ci-qflistudio-next-ef5e222e5b54-45161937167.json").read_text(
        encoding="utf-8"
    )
)
repo = record["repo"]
run_id = record["run_id"]

env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never")
result = subprocess.run(
    ["git", "credential", "fill"],
    input=f"protocol=https\nhost=github.com\npath=azurekiln2333/{repo}.git\n\n",
    text=True,
    capture_output=True,
    env=env,
    timeout=30,
)
credential = dict(
    line.split("=", 1) for line in result.stdout.splitlines() if "=" in line
)
if not credential.get("password"):
    raise SystemExit("No stored GitHub credential for artifact access")

headers = {
    "User-Agent": "qfli-mobile-integration-review",
    "Authorization": "Bearer " + credential["password"],
}


def api(url):
    request = urllib.request.Request(url, headers=headers)
    with opener.open(request, timeout=30) as response:
        return response.read()


artifacts = json.loads(
    api(f"https://api.github.com/repos/azurekiln2333/{repo}/actions/runs/{run_id}/artifacts")
)["artifacts"]
for artifact in artifacts:
    print(f"artifact: {artifact['name']} size={artifact['size_in_bytes']}")

target = None
for artifact in artifacts:
    if artifact["name"] == f"git-ios-integration-{run_id}":
        target = artifact
        break
if target is None:
    raise SystemExit("git-ios-integration artifact not present")

blob = api(target["archive_download_url"])
out_zip = here / f"takeover-artifact-{run_id}-git-ios.zip"
out_zip.write_bytes(blob)
print(f"downloaded {len(blob)} bytes -> {out_zip.name}")

with zipfile.ZipFile(io.BytesIO(blob)) as archive:
    for name in archive.namelist():
        data = archive.read(name)
        flat = name.replace("/", "_")
        destination = here / f"takeover-artifact-{run_id}-{flat}"
        destination.write_bytes(data)
        print(f"extracted {name} ({len(data)} bytes) -> {destination.name}")
