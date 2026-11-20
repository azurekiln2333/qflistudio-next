#!/usr/bin/env python3
"""Record and verify the qfli_git revision in an app build.

The app consumes qfli_git transitively through the shared core. The resolved
Git commit, the native lock and the CA bundle must all agree before a release
artifact is staged. Build jobs record the facts; release staging requires them.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit
import re
import subprocess
import sys

PLUGIN_NAME = "qfli_git"
EXPECTED_URL = "https://github.com/azurekiln2333/qflistudio-git"
REQUIRED_FACTS = (
    "QFLI_PLUGIN_COMMIT",
    "QFLI_PLUGIN_VERSION",
    "QFLI_PLUGIN_API_VERSION",
    "QFLI_PLUGIN_NATIVE_SOURCE",
    "QFLI_PLUGIN_NATIVE_RELEASE",
    "QFLI_PLUGIN_CACERT_SHA256",
)


class ProvenanceError(RuntimeError):
    """Raised when the app graph does not carry a verifiable plugin revision."""


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ProvenanceError(f"Cannot read {path}: {error}") from error


def full_commit(value: object) -> str:
    if not isinstance(value, str) or len(value) != 40:
        raise ProvenanceError(f"Not a full Git commit: {value!r}")
    if any(character not in "0123456789abcdef" for character in value.lower()):
        raise ProvenanceError(f"Not a hexadecimal Git commit: {value!r}")
    return value.lower()


def file_uri_path(value: str, base: Path) -> Path:
    parsed = urlsplit(value)
    if parsed.scheme == "file":
        path = unquote(parsed.path)
        if re.match(r"^/[A-Za-z]:/", path):
            path = path[1:]
        return Path(path)
    if parsed.scheme:
        raise ProvenanceError(f"Unsupported package root URI: {value}")
    return (base / value).resolve()


def package_root(app_root: Path) -> Path:
    config = app_root / ".dart_tool/package_config.json"
    if not config.is_file():
        raise ProvenanceError(
            "Run flutter pub get first: .dart_tool/package_config.json is missing"
        )
    data = load_json(config)
    for package in data.get("packages", []):
        if package.get("name") == PLUGIN_NAME:
            root = package.get("rootUri")
            if not isinstance(root, str) or not root:
                raise ProvenanceError(f"{PLUGIN_NAME} has no rootUri")
            return file_uri_path(root, config.parent).resolve()
    raise ProvenanceError(f"{PLUGIN_NAME} is not in the resolved package graph")


def load_lock_yaml(path: Path) -> dict:
    """Read pubspec.lock, which is YAML, not JSON.

    The lock is a YAML mapping, so `json.loads` always raises. PyYAML is used
    when it is importable; otherwise a small reader handles the fixed shape pub
    writes: two-space indented `packages:` entries with scalar fields and a
    nested `description:` block. Both readers apply the same validation.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        raise ProvenanceError(f"Cannot read {path}: {error}") from error
    try:
        import yaml  # type: ignore[import-not-found]
    except ImportError:
        data = parse_lock_subset(text)
    else:
        try:
            data = yaml.safe_load(text)
        except yaml.YAMLError as error:  # type: ignore[attr-defined]
            raise ProvenanceError(f"Cannot parse {path}: {error}") from error
    if not isinstance(data, dict):
        raise ProvenanceError(f"{path} is not a YAML mapping")
    # Both readers must agree: an empty or missing packages mapping is a broken
    # lock, not an empty package graph. PyYAML reports a bare `packages:` key
    # as None, so this has to be checked here rather than in lock_entry.
    packages = data.get("packages")
    if not isinstance(packages, dict) or not packages:
        raise ProvenanceError(f"{path} has no packages section")
    return data


def parse_lock_subset(text: str) -> dict:
    """Parse the subset of YAML that pubspec.lock uses."""
    packages: dict[str, dict] = {}
    current: dict | None = None
    description: dict | None = None
    in_packages = False
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        line = raw.strip()
        if indent == 0:
            in_packages = line.startswith("packages:")
            current = None
            description = None
            continue
        if not in_packages:
            continue
        if indent == 2 and line.endswith(":"):
            name = line[:-1].strip().strip("'\"")
            current = {}
            description = None
            packages[name] = current
            continue
        if current is None:
            continue
        if indent == 4:
            if line == "description:":
                description = {}
                current["description"] = description
                continue
            key, _, value = line.partition(":")
            current[key.strip()] = scalar(value)
            continue
        if indent == 6 and description is not None:
            key, _, value = line.partition(":")
            description[key.strip()] = scalar(value)
    if not packages:
        raise ProvenanceError("pubspec.lock has no packages section")
    return {"packages": packages}


def scalar(value: str) -> str | None:
    value = value.strip()
    if not value or value == "null":
        return None
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def lock_entry(app_root: Path) -> dict:
    path = app_root / "pubspec.lock"
    if not path.is_file():
        raise ProvenanceError("pubspec.lock is missing")
    data = load_lock_yaml(path)
    entry = data.get("packages", {}).get(PLUGIN_NAME)
    if not isinstance(entry, dict):
        raise ProvenanceError(f"pubspec.lock has no {PLUGIN_NAME} entry")
    if entry.get("source") != "git":
        raise ProvenanceError(
            f"{PLUGIN_NAME} is resolved from {entry.get('source')!r}, not a Git commit"
        )
    description = entry.get("description")
    if not isinstance(description, dict):
        raise ProvenanceError(f"{PLUGIN_NAME} has no Git description")
    url = str(description.get("url", ""))
    if EXPECTED_URL not in url:
        raise ProvenanceError(f"{PLUGIN_NAME} comes from an unexpected URL: {url}")
    ref = description.get("resolved-ref") or description.get("ref")
    return {
        "commit": full_commit(ref),
        "url": url,
        "version": str(entry.get("version", "")),
    }


def plugin_contract(plugin_root: Path) -> dict:
    contract = plugin_root / "tool/ci/native_contract.json"
    if not contract.is_file():
        raise ProvenanceError(
            "The pinned plugin has no tool/ci/native_contract.json; "
            "pin a commit that contains the new native contract"
        )
    data = load_json(contract)
    version = data.get("apiVersion")
    exports = data.get("requiredExports")
    if not isinstance(version, int) or isinstance(version, bool) or version <= 0:
        raise ProvenanceError("native_contract.json has no positive apiVersion")
    if not isinstance(exports, list) or not exports:
        raise ProvenanceError("native_contract.json has no requiredExports")
    data["sha256"] = digest(contract)
    return data


def plugin_native_state(plugin_root: Path, contract: dict) -> dict:
    lock_path = plugin_root / "native_libs.lock.json"
    lock = load_json(lock_path)
    if lock.get("schemaVersion") != 2:
        raise ProvenanceError(
            "native_libs.lock.json is not schema 2; import the cloud-built artifacts"
        )
    if lock.get("apiVersion") != contract["apiVersion"]:
        raise ProvenanceError(
            f"Lock API version {lock.get('apiVersion')!r} != "
            f"{contract['apiVersion']!r}"
        )
    if lock.get("requiredExports") != contract["requiredExports"]:
        raise ProvenanceError("Lock required exports do not match the contract")
    if lock.get("contractSha256") != contract["sha256"]:
        raise ProvenanceError("Lock was written against a different contract file")
    source = lock.get("source")
    if not isinstance(source, dict):
        raise ProvenanceError("Native lock has no source block")
    commit = full_commit(source.get("commit"))
    commits = source.get("commits")
    if not isinstance(commits, dict) or set(commits) != {"android", "ios", "ohos"}:
        raise ProvenanceError("Native lock has no per-platform source commits")
    for platform, value in commits.items():
        if full_commit(value) != commit:
            raise ProvenanceError(
                f"{platform} native source {value} != {commit}"
            )
    records = lock.get("files")
    if not isinstance(records, list) or not records:
        raise ProvenanceError("Native lock records no files")
    for record in records:
        relative = PurePosixPath(str(record.get("path", "")))
        if not relative.parts or relative.is_absolute() or ".." in relative.parts:
            raise ProvenanceError(f"Unsafe lock path: {record.get('path')!r}")
        target = plugin_root / relative
        if not target.is_file():
            raise ProvenanceError(f"Locked library is missing: {relative}")
        if target.stat().st_size != record.get("bytes"):
            raise ProvenanceError(f"{relative} has a different size from the lock")
        if digest(target) != str(record.get("sha256", "")).lower():
            raise ProvenanceError(f"{relative} has a different SHA-256 from the lock")
    cacert = plugin_root / "assets/cacert.pem"
    if not cacert.is_file() or cacert.stat().st_size == 0:
        raise ProvenanceError("The pinned plugin has no assets/cacert.pem")
    api = read_plugin_api(plugin_root)
    if api != contract["apiVersion"]:
        raise ProvenanceError(
            f"Plugin Dart/header API version {api} does not match native "
            f"{contract['apiVersion']}"
        )
    return {
        "apiVersion": contract["apiVersion"],
        "commit": commit,
        "release": str(source.get("release") or ""),
        "run": str(source.get("run") or ""),
        "cacert": digest(cacert),
        "lockSha256": digest(lock_path),
    }


def read_plugin_api(plugin_root: Path) -> int:
    bindings = (plugin_root / "lib/src/bindings.dart").read_text(encoding="utf-8")
    dart = re.search(r"const int qgApiVersion\s*=\s*(\d+)\s*;", bindings)
    header = (plugin_root / "native/include/qfli_git.h").read_text(encoding="utf-8")
    c_api = re.search(r"#define\s+QG_API_VERSION\s+(\d+)", header)
    if not dart or not c_api:
        raise ProvenanceError("The plugin does not declare a native API version")
    if dart.group(1) != c_api.group(1):
        raise ProvenanceError(
            f"Dart binding API {dart.group(1)} != header API {c_api.group(1)}"
        )
    return int(dart.group(1))


def run_plugin_check(plugin_root: Path) -> None:
    script = plugin_root / "tool/ci/check_native_install.py"
    if not script.is_file():
        raise ProvenanceError(
            "The pinned plugin has no tool/ci/check_native_install.py"
        )
    result = subprocess.run(
        [sys.executable, str(script), "--repo-root", str(plugin_root)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise ProvenanceError(f"Plugin native check failed: {detail}")


def collect(app_root: Path, strict: bool) -> dict:
    root = package_root(app_root)
    entry = lock_entry(app_root)
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    version_match = re.search(r"^version:\s*(\S+)\s*$", pubspec, re.MULTILINE)
    if not version_match:
        raise ProvenanceError("The pinned plugin pubspec.yaml has no version")
    facts = {
        "QFLI_PLUGIN_COMMIT": entry["commit"],
        "QFLI_PLUGIN_VERSION": version_match.group(1),
        "QFLI_PLUGIN_URL": entry["url"],
        "QFLI_PLUGIN_ROOT": str(root),
        "QFLI_PLUGIN_API_VERSION": "",
        "QFLI_PLUGIN_NATIVE_SOURCE": "",
        "QFLI_PLUGIN_NATIVE_RELEASE": "",
        "QFLI_PLUGIN_CACERT_SHA256": "",
        "QFLI_PLUGIN_LOCK_SHA256": "",
        # Always present so a caller under `set -u` can read it directly.
        "QFLI_PLUGIN_PENDING": "0",
    }
    try:
        contract = plugin_contract(root)
        native = plugin_native_state(root, contract)
        if strict:
            run_plugin_check(root)
        facts.update(
            {
                "QFLI_PLUGIN_API_VERSION": str(native["apiVersion"]),
                "QFLI_PLUGIN_NATIVE_SOURCE": native["commit"],
                "QFLI_PLUGIN_NATIVE_RELEASE": native["release"] or native["run"],
                "QFLI_PLUGIN_CACERT_SHA256": native["cacert"],
                "QFLI_PLUGIN_LOCK_SHA256": native["lockSha256"],
            }
        )
    except ProvenanceError:
        if strict:
            raise
        facts["QFLI_PLUGIN_PENDING"] = "1"
    return facts


def write_env(path: Path, facts: dict) -> None:
    with path.open("a", encoding="utf-8") as stream:
        for key, value in facts.items():
            if "\n" in value or "\r" in value:
                raise ProvenanceError(f"{key} contains a line break")
            stream.write(f"{key}={value}\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-root", type=Path, default=Path.cwd())
    parser.add_argument("--write-env", type=Path)
    parser.add_argument("--require-release-ready", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        facts = collect(args.app_root.resolve(), args.require_release_ready)
        if args.require_release_ready:
            missing = [name for name in REQUIRED_FACTS if not facts.get(name)]
            if missing:
                raise ProvenanceError(
                    "Release needs a pinned plugin with imported native artifacts; "
                    "missing: " + ", ".join(missing)
                )
        if args.write_env:
            write_env(args.write_env, facts)
        if args.json:
            print(json.dumps(facts, indent=2, sort_keys=True))
        elif not args.write_env:
            for key in sorted(facts):
                print(f"{key}={facts[key]}")
    except (ProvenanceError, OSError) as error:
        print(f"plugin_provenance: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())