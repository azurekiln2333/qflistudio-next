#!/usr/bin/env python3
"""Inspect an existing main Flutter asset bundle without building or writing files.

From the qflistudio root, after the official bundle build:
  python .trellis/tasks/10-23-studio-release-ux-workspaces/research/inspect-main-content-bundle.py build/flutter_assets

The decoder follows the local Flutter SDK's services/asset_manifest.dart,
services/message_codecs.dart and foundation/serialization.dart. The web wrapper
is a JSON string containing base64 of the same StandardMessageCodec message.
Codec numeric byte order belongs to the build host; use --byte-order when
inspecting a bundle produced on a host with a different byte order.

Existing sibling helpers were checked first. WebForge's run_ohos_catalog.py
checks archive bytes/hashes but also owns HAP/signing/device operations; this
directory-only inspector has no dependency on that product or its tooling.
"""

from __future__ import annotations

import argparse
import base64
import binascii
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path, PurePosixPath, PureWindowsPath
import struct
import sys


CONTENT_KEYS = (
    "assets/content/tutorials.json",
    "assets/content/examples.json",
    "assets/content/provenance.json",
)
SUBJECTS = {
    "c", "cpp", "lua", "javascript", "typescript", "shell", "rust", "go",
    "java", "html", "css", "python", "dart", "sql", "json", "markdown",
}


class InspectionError(Exception):
    """An incomplete, stale or malformed asset bundle."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InspectionError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fnv1a32(data: bytes) -> str:
    value = 0x811C9DC5
    for byte in data:
        value = ((value ^ byte) * 0x01000193) & 0xFFFFFFFF
    return f"{value:08x}"


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, f"JSON contains duplicate object key: {key!r}")
        result[key] = value
    return result


def strict_json(data: bytes, label: str) -> object:
    def reject_constant(value: str) -> None:
        raise InspectionError(f"{label}: invalid JSON constant {value}")

    try:
        return json.loads(
            data.decode("utf-8"), object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise InspectionError(f"{label}: invalid UTF-8 JSON: {error}") from error


def contained_file(root: Path, key: str) -> Path:
    require(isinstance(key, str) and bool(key), "Empty or non-string asset path")
    parts = key.split("/")
    require(
        "\\" not in key and not PurePosixPath(key).is_absolute()
        and not PureWindowsPath(key).drive
        and all(part not in ("", ".", "..") for part in parts),
        f"Asset path is not a relative bundle path: {key!r}",
    )
    candidate = root.joinpath(*parts).resolve()
    require(candidate.is_relative_to(root), f"Asset path escapes bundle root: {key!r}")
    require(candidate.is_file(), f"Missing asset file: {candidate}")
    return candidate


class FileSnapshot:
    def __init__(self) -> None:
        self.files: dict[Path, bytes] = {}

    def read(self, path: Path) -> bytes:
        before = path.stat()
        data = path.read_bytes()
        after = path.stat()
        require(
            (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns),
            f"File changed while reading: {path}",
        )
        if path in self.files:
            require(self.files[path] == data, f"File changed during inspection: {path}")
        self.files[path] = data
        return data

    def verify_unchanged(self) -> None:
        for path, data in self.files.items():
            require(path.read_bytes() == data, f"File changed during inspection: {path}")


class StandardMessageReader:
    """Read Flutter's base codec; manifest maps require unique string keys."""

    def __init__(self, data: bytes, byte_order: str) -> None:
        self.data = data
        self.offset = 0
        self.endian = "<" if byte_order == "little" else ">"

    def take(self, count: int) -> bytes:
        require(0 <= count <= len(self.data) - self.offset, "Truncated StandardMessageCodec message")
        result = self.data[self.offset:self.offset + count]
        self.offset += count
        return result

    def number(self, code: str) -> int | float:
        return struct.unpack(self.endian + code, self.take(struct.calcsize(code)))[0]

    def align(self, width: int) -> None:
        self.take((-self.offset) % width)

    def size(self) -> int:
        marker = self.take(1)[0]
        if marker == 254:
            return int(self.number("H"))
        if marker == 255:
            return int(self.number("I"))
        return marker

    def value(self, depth: int = 0) -> object:
        require(depth < 128, "StandardMessageCodec nesting exceeds 128 levels")
        tag = self.take(1)[0]
        if tag == 0:
            return None
        if tag in (1, 2):
            return tag == 1
        if tag in (3, 4):
            return self.number("i" if tag == 3 else "q")
        if tag == 6:
            self.align(8)
            return self.number("d")
        if tag in (5, 7):
            try:
                return self.take(self.size()).decode("utf-8")
            except UnicodeDecodeError as error:
                raise InspectionError("Invalid UTF-8 in StandardMessageCodec string") from error
        if tag == 8:
            return self.take(self.size())
        if tag in (9, 10, 11, 14):
            count = self.size()
            code = {9: "i", 10: "q", 11: "d", 14: "f"}[tag]
            width = struct.calcsize(code)
            self.align(width)
            return list(struct.unpack(self.endian + str(count) + code, self.take(count * width)))
        if tag == 12:
            count = self.size()
            require(count <= len(self.data) - self.offset, "Truncated codec list")
            return [self.value(depth + 1) for _ in range(count)]
        if tag == 13:
            count = self.size()
            require(count * 2 <= len(self.data) - self.offset, "Truncated codec map")
            result = {}
            for _ in range(count):
                key = self.value(depth + 1)
                require(isinstance(key, str), "Asset manifest map key is not a string")
                require(key not in result, f"Duplicate asset manifest map key: {key!r}")
                result[key] = self.value(depth + 1)
            return result
        raise InspectionError(f"Unsupported StandardMessageCodec type tag {tag} at byte {self.offset - 1}")

    def decode(self) -> dict:
        result = self.value()
        require(self.offset == len(self.data), "Trailing bytes in StandardMessageCodec message")
        require(isinstance(result, dict), "Asset manifest codec message is not a map")
        return result


def load_manifests(bundle: Path, snapshots: FileSnapshot, byte_order: str) -> tuple[dict, list[dict]]:
    decoded = None
    records = []
    for name in ("AssetManifest.bin", "AssetManifest.bin.json"):
        path = bundle / name
        if not path.exists():
            continue
        data = snapshots.read(contained_file(bundle, name))
        payload = data
        if name.endswith(".json"):
            wrapped = strict_json(data, name)
            require(isinstance(wrapped, str), f"{name}: expected a JSON string containing base64")
            try:
                payload = base64.b64decode(wrapped, validate=True)
            except (ValueError, binascii.Error) as error:
                raise InspectionError(f"{name}: invalid base64 wrapper") from error
        manifest = StandardMessageReader(payload, byte_order).decode()
        if decoded is not None:
            require(manifest == decoded, "AssetManifest.bin and AssetManifest.bin.json disagree")
        decoded = manifest
        records.append({"path": name, "bytes": len(data), "sha256": sha256(data)})
    require(decoded is not None, f"Missing AssetManifest.bin or AssetManifest.bin.json in {bundle}")
    return decoded, records


def inspect_catalog(document: object, kind: str, label: str) -> dict:
    require(isinstance(document, dict), f"{label}: catalog is not an object")
    require(document.get("schemaVersion") == 1, f"{label}: unexpected schemaVersion")
    require(document.get("kind") == kind, f"{label}: expected kind {kind!r}")
    entries = document.get("entries")
    require(isinstance(entries, list) and bool(entries), f"{label}: missing or empty entries")
    ids = set()
    counts = Counter()
    lessons = Counter()
    for index, row in enumerate(entries):
        require(isinstance(row, dict), f"{label}: entries[{index}] is not an object")
        row_id = row.get("id")
        require(isinstance(row_id, str) and bool(row_id.strip()), f"{label}: entries[{index}] lacks an id")
        require(row_id not in ids, f"{label}: duplicate id {row_id!r}")
        ids.add(row_id)
        language = row.get("language") or row.get("type")
        require(isinstance(language, str), f"{label}: {row_id} lacks a subject")
        language = language.strip().lower()
        counts[language] += 1
        if kind == "tutorials":
            if isinstance(row.get("lessons"), list):
                lessons[language] += len(row["lessons"])
            else:
                chapters = row.get("chapters")
                require(isinstance(chapters, list), f"{label}: {row_id} lacks lessons/chapters")
                for chapter in chapters:
                    require(isinstance(chapter, dict) and isinstance(chapter.get("lessons"), list), f"{label}: {row_id} has malformed chapters")
                    lessons[language] += len(chapter["lessons"])
    require(set(counts) == SUBJECTS, f"{label}: expected all 16 subjects; got {sorted(counts)}")
    require(counts["c"] > 0 and counts["cpp"] > 0, f"{label}: C and CPP must be separate non-empty subjects")
    return {"entries": len(entries), "subjects": dict(sorted(counts.items())), "lessons": dict(sorted(lessons.items()))}


def inspect(bundle: Path, source_root: Path, byte_order: str) -> dict:
    bundle = bundle.resolve()
    source_root = source_root.resolve()
    require(bundle.is_dir(), f"Missing Flutter asset bundle directory: {bundle}")
    require(source_root.is_dir(), f"Missing main source directory: {source_root}")
    require(bundle != source_root, "Bundle and main source directory must differ")
    snapshots = FileSnapshot()
    source_bytes = {key: snapshots.read(contained_file(source_root, key)) for key in CONTENT_KEYS}
    source_json = {key: strict_json(data, f"main source {key}") for key, data in source_bytes.items()}
    manifest, manifests = load_manifests(bundle, snapshots, byte_order)
    registrations = {}
    packaged = {}
    for key in CONTENT_KEYS:
        require(key in manifest, f"Asset manifest does not register logical key: {key}")
        variants = manifest[key]
        require(isinstance(variants, list) and bool(variants), f"Missing manifest variants for {key}")
        paths = []
        for variant in variants:
            require(isinstance(variant, dict), f"Malformed manifest variant for {key}")
            asset = variant.get("asset")
            require(isinstance(asset, str) and bool(asset), f"Variant lacks an asset path for {key}")
            require(asset not in paths, f"Duplicate manifest variant {asset!r} for {key}")
            dpr = variant.get("dpr")
            require(dpr is None or (isinstance(dpr, (int, float)) and not isinstance(dpr, bool) and math.isfinite(dpr) and dpr > 0), f"Invalid variant dpr for {key}")
            payload = snapshots.read(contained_file(bundle, asset))
            require(payload == source_bytes[key], f"Packaged variant differs from current main bytes/SHA256: {asset}; expected {sha256(source_bytes[key])}, got {sha256(payload)}")
            strict_json(payload, f"packaged variant {asset}")
            paths.append(asset)
            packaged[asset] = {"bytes": len(payload), "sha256": sha256(payload)}
        require(key in paths, f"Manifest lacks the main asset variant {key!r}")
        registrations[key] = paths

    catalogs = {}
    for kind in ("tutorials", "examples"):
        key = f"assets/content/{kind}.json"
        payload = snapshots.read(contained_file(bundle, key))
        catalogs[kind] = inspect_catalog(strict_json(payload, f"packaged {key}"), kind, key)
    provenance = source_json["assets/content/provenance.json"]
    require(isinstance(provenance, dict) and provenance.get("schemaVersion") == 1, "Malformed content provenance")
    require(isinstance(provenance.get("sources"), list) and len(provenance["sources"]) == 27, "Provenance must record 27 content sources")
    counts = provenance.get("counts")
    require(isinstance(counts, dict), "Provenance lacks counts")
    for kind, catalog in catalogs.items():
        require(counts.get(kind) == catalog["subjects"], f"Provenance {kind} subject counts differ from packaged JSON")
    require(provenance.get("lessonCounts") == catalogs["tutorials"]["lessons"], "Provenance lesson counts differ from packaged tutorials")
    outputs = provenance.get("outputs")
    require(isinstance(outputs, list) and len(outputs) == 2, "Provenance must record two catalog outputs")
    output_records = {}
    for record in outputs:
        require(isinstance(record, dict) and isinstance(record.get("path"), str), "Malformed provenance output record")
        key = record["path"]
        require(key not in output_records, f"Duplicate provenance output record: {key}")
        output_records[key] = record
    require(set(output_records) == set(CONTENT_KEYS[:2]), "Provenance output paths do not match the two catalogs")
    for key, record in output_records.items():
        require(record.get("bytes") == len(source_bytes[key]) and record.get("fingerprint") == fnv1a32(source_bytes[key]), f"Provenance bytes/FNV-1a fingerprint differs from current main catalog: {key}")
    snapshots.verify_unchanged()
    return {
        "status": "PASS",
        "inspectedAtUtc": datetime.now(timezone.utc).isoformat(),
        "bundleDirectory": str(bundle),
        "mainSourceDirectory": str(source_root),
        "codecByteOrder": byte_order,
        "manifests": manifests,
        "manifestLogicalKeyCount": len(manifest),
        "contentRegistrations": registrations,
        "packagedContentFiles": packaged,
        "catalogs": catalogs,
        "provenanceSources": len(provenance["sources"]),
        "allInspectedFilesUnchangedDuringInspection": True,
        "proofScope": "Existing Flutter asset directory bytes, content counts and binary-manifest registration.",
        "limitations": ["No executable, HAP/APK/archive, installation, launch or device runtime validation."],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("bundle", type=Path, help="Existing Flutter asset directory, for example build/flutter_assets")
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[4], help="Main qflistudio source root; defaults to this task's repository")
    parser.add_argument("--byte-order", choices=("little", "big"), default=sys.byteorder, help="Manifest build-host byte order; defaults to this Python host")
    args = parser.parse_args()
    try:
        result = inspect(args.bundle, args.source_root, args.byte_order)
    except (InspectionError, OSError, RecursionError, struct.error) as error:
        print(json.dumps({"status": "FAIL", "error": str(error)}, ensure_ascii=True), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
