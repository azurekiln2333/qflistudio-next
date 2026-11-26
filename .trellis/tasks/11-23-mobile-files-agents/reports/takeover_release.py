"""Read-only verification of the mobile task's published GitHub release."""

import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).parent
BASE = "https://api.github.com/repos/azurekiln2333/qflistudio-next"
APP = "055dd223e4641419cc8e603405a134508508094c"
CORE = "d3d899571382121d3b5d69dd36b60222e5fa0b37"
TAG = "v5.0.11"
VERSION = "5.0.11"
RUN = 45167787307

result = subprocess.run(
    ["git", "credential", "fill"],
    input="protocol=https\nhost=github.com\n\n",
    text=True, capture_output=True, timeout=20,
    env=dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never"),
)
credential = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
headers = {"User-Agent": "qfli-mobile-release-review"}
if credential.get("password"):
    headers["Authorization"] = "Bearer " + credential["password"]


def get(path):
    request = urllib.request.Request(BASE + path, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


try:
    release = get("/releases/tags/" + TAG)
except urllib.error.HTTPError as error:
    if error.code == 404:
        print(f"{TAG}: release is not published yet")
        raise SystemExit(0)
    raise

ref = get("/git/ref/tags/" + TAG)["object"]
if ref["type"] == "tag":
    ref = get("/git/tags/" + ref["sha"])["object"]
if ref["type"] != "commit" or ref["sha"] != APP:
    raise SystemExit("Tag does not resolve to the verified App commit")
if release["draft"] or release["prerelease"] or not release["published_at"]:
    raise SystemExit("Release is not a published stable release")
body = release.get("body") or ""
if APP not in body or CORE not in body or f"/actions/runs/{RUN}" not in body:
    raise SystemExit("Release notes do not identify the verified source and run")
run = get(f"/actions/runs/{RUN}")
if run["head_sha"] != APP or run["status"] != "completed" or run["conclusion"] != "success":
    raise SystemExit("Release workflow has not completed successfully at the expected commit")

targets = (
    "windows-x64", "windows-arm64", "linux-x64", "linux-arm64",
    "macos-x86_64", "macos-arm64", "ios-arm64", "android-x86_64",
    "android-armeabi-v7a", "android-arm64-v8a", "ohos-arm64",
)
zips = {f"qflistudio-{VERSION}-{target}.zip" for target in targets}
zips.add(f"qfli-remote-assistant-{VERSION}-windows-x64.zip")
assets = {item["name"]: item for item in release["assets"]}
if set(assets) != zips | {"SHA256SUMS"} or len(assets) != len(release["assets"]):
    raise SystemExit("Published asset set differs from the twelve ZIPs and SHA256SUMS")
for name, asset in assets.items():
    if asset["state"] != "uploaded" or asset["size"] <= 0:
        raise SystemExit(f"Asset is not fully uploaded: {name}")

# The public download uses no credential and only fetches the small manifest.
request = urllib.request.Request(
    assets["SHA256SUMS"]["browser_download_url"],
    headers={"User-Agent": "qfli-mobile-release-review"},
)
with urllib.request.urlopen(request, timeout=30) as response:
    data = response.read(65537)
if len(data) > 65536:
    raise SystemExit("Unexpectedly large checksum manifest")
checksums = {}
for line in data.decode("utf-8").splitlines():
    match = re.fullmatch(r"([0-9a-f]{64}) [ *](?:\./)?([^/]+\.zip)", line)
    if not match or match[2] in checksums:
        raise SystemExit("Invalid or duplicate checksum entry")
    checksums[match[2]] = match[1]
if set(checksums) != zips:
    raise SystemExit("Checksum manifest does not cover every ZIP exactly once")
digest_results = {}
for name, expected in checksums.items():
    actual = assets[name].get("digest")
    if actual != "sha256:" + expected:
        raise SystemExit(f"GitHub asset digest mismatch or missing digest: {name}")
    digest_results[name] = expected
manifest_digest = "sha256:" + hashlib.sha256(data).hexdigest()
if assets["SHA256SUMS"].get("digest") != manifest_digest:
    raise SystemExit("Downloaded checksum manifest differs from the GitHub asset digest")

record = {
    "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "app_commit": APP, "core_commit": CORE, "run_id": RUN,
    "tag": TAG, "tag_commit": ref["sha"], "release": release,
    "checksums_match_github_digests": digest_results,
    "manifest_digest": manifest_digest,
    "zip_payloads_downloaded_locally": False,
    "physical_device_validation": False,
}
output = ROOT / "takeover-release-v5.0.11.json"
output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(ROOT / "takeover-release-v5.0.11-SHA256SUMS").write_bytes(data)
print(f"Verified {TAG}: 11 application ZIPs, 1 Windows assistant ZIP, SHA256SUMS")
print("All ZIP manifest hashes match GitHub asset digests; ZIP payloads were not downloaded")
print(f"App {APP}; Core {CORE}; successful release run {RUN}")
print(f"Published: {release['published_at']}; release ID: {release['id']}")
print(f"Evidence: {output}")
