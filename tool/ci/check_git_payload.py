#!/usr/bin/env python3
"""Assert that an app package really carries the qfli_git native library and CA.

The checks run on the staged package, not on the build directory, so a plugin
that is resolved but never packaged fails here.

The packed library is checked for format, ABI and exported symbols, not for
byte equality with native_libs.lock.json. Android strips the shared object and
iOS codesigns the framework binary while packaging, so the packaged bytes
legitimately differ from the imported artifact. `--lock` ties the package back
to the lock through the facts that survive packaging: the native contract and
the CA bundle digest.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

LIBRARY_NAME = "libqfli_git.so"
CA_SUFFIX = "packages/qfli_git/assets/cacert.pem"
ELF_MACHINES = {
    "arm64-v8a": 183,  # EM_AARCH64
    "armeabi-v7a": 40,  # EM_ARM
    "x86_64": 62,  # EM_X86_64
}
MACHO_ARM64 = 0x0100000C


class PayloadError(RuntimeError):
    """Raised when a package lacks the required Git payload."""


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def native_entry(platform: str, abi: str | None) -> str:
    if platform in ("android", "ohos"):
        if not abi:
            raise PayloadError(f"{platform} needs --abi")
        folder = "lib" if platform == "android" else "libs"
        return f"{folder}/{abi}/{LIBRARY_NAME}"
    if platform == "ios":
        return "Payload/Runner.app/Frameworks/qfli_git.framework/qfli_git"
    raise PayloadError(f"Unsupported platform: {platform}")


def ca_entries(names: list[str]) -> list[str]:
    return [name for name in names if name.endswith(CA_SUFFIX)]


def check_elf(data: bytes, abi: str) -> None:
    expected_class = 1 if abi == "armeabi-v7a" else 2
    if data[:4] != b"ELF" or data[4] != expected_class:
        raise PayloadError(
            f"packed library is not a {expected_class * 32}-bit ELF image"
        )
    machine = int.from_bytes(data[18:20], "little")
    expected = ELF_MACHINES[abi]
    if machine != expected:
        raise PayloadError(
            f"packed library machine is {machine}, expected {expected} for {abi}"
        )


def check_macho(data: bytes) -> None:
    if len(data) < 8:
        raise PayloadError("packed framework binary is truncated")
    magic = int.from_bytes(data[:4], "little")
    if magic not in (0xFEEDFACF, 0xFEEDFACE):
        raise PayloadError("packed framework binary is not a Mach-O image")
    cpu = int.from_bytes(data[4:8], "little")
    if cpu != MACHO_ARM64:
        raise PayloadError(
            f"packed framework CPU type is {cpu:#x}, expected {MACHO_ARM64:#x}"
        )


def defined_symbols(data: bytes, nm: str, macho: bool) -> set[str]:
    with tempfile.TemporaryDirectory(prefix="qfli-git-payload-") as work:
        library = Path(work) / LIBRARY_NAME
        library.write_bytes(data)
        arguments = [nm, "-gU"] if macho else [nm, "-D", "--defined-only"]
        try:
            output = subprocess.run(
                arguments + [str(library)],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
        except (OSError, subprocess.CalledProcessError) as error:
            raise PayloadError(f"{nm} cannot read the packed library: {error}") from error
    symbols = set()
    for line in output.splitlines():
        fields = line.split()
        if not fields:
            continue
        name = fields[-1]
        if name.startswith("__"):
            continue
        if name.startswith("_"):
            name = name[1:]
        if name:
            symbols.add(name)
    return symbols


def load_required(contract: Path | None, platform: str) -> list[str]:
    if contract is None:
        return []
    data = json.loads(contract.read_text(encoding="utf-8"))
    required = data.get("requiredExports")
    if not isinstance(required, list) or not required:
        raise PayloadError(f"{contract} has no requiredExports")
    if data.get("apiVersion") is None:
        raise PayloadError(f"{contract} has no apiVersion")
    return list(required)


def load_lock(path: Path, contract: Path | None) -> dict:
    """Read the plugin native lock and check it against the contract."""
    try:
        lock = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PayloadError(f"Cannot read {path}: {error}") from error
    if lock.get("schemaVersion") != 2:
        raise PayloadError(f"{path} is not schema 2")
    if contract is not None:
        data = json.loads(contract.read_text(encoding="utf-8"))
        if lock.get("apiVersion") != data.get("apiVersion"):
            raise PayloadError(
                f"{path} API {lock.get('apiVersion')!r} != contract "
                f"{data.get('apiVersion')!r}"
            )
        if lock.get("requiredExports") != data.get("requiredExports"):
            raise PayloadError(f"{path} required exports do not match the contract")
        if digest(contract.read_bytes()) != lock.get("contractSha256"):
            raise PayloadError(f"{path} was written against a different contract")
    return lock


def lock_cacert(lock: dict, plugin_root: Path) -> str:
    """Return the CA digest the lock expects for the packaged asset."""
    entry = plugin_root / "assets/cacert.pem"
    if not entry.is_file():
        raise PayloadError(f"Missing CA bundle: {entry}")
    return digest(entry.read_bytes())


def check(
    platform: str,
    archive: Path,
    abi: str | None,
    contract: Path | None,
    cacert_sha256: str | None,
    nm: str | None,
    lock: dict | None = None,
) -> dict:
    if not archive.is_file() or archive.stat().st_size == 0:
        raise PayloadError(f"Missing package: {archive}")
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        entry = native_entry(platform, abi)
        matches = [name for name in names if name == entry]
        if not matches:
            raise PayloadError(f"{archive.name} has no {entry}")
        data = bundle.read(entry)
        if not data:
            raise PayloadError(f"{entry} is empty")
        if platform in ("android", "ohos"):
            check_elf(data, abi or "")
        else:
            check_macho(data)
        cas = ca_entries(names)
        if len(cas) != 1:
            raise PayloadError(
                f"{archive.name} has {len(cas)} qfli_git CA entries, expected one"
            )
        ca = bundle.read(cas[0])
        if not ca:
            raise PayloadError(f"{cas[0]} is empty")
        ca_sha = digest(ca)
        if cacert_sha256 and ca_sha != cacert_sha256.lower():
            raise PayloadError(
                f"{cas[0]} SHA-256 is {ca_sha}, expected {cacert_sha256}"
            )
    required = load_required(contract, platform)
    if lock is not None and required != list(lock.get("requiredExports", [])):
        raise PayloadError("The packed library contract differs from the native lock")
    symbols = set()
    if nm and required:
        symbols = defined_symbols(data, nm, platform == "ios")
        missing = sorted(set(required) - symbols)
        if missing:
            raise PayloadError(
                "packed library lacks required exports: " + ", ".join(missing)
            )
    return {
        "entry": entry,
        "bytes": len(data),
        "packedSha256": digest(data),
        "cacert": ca_sha,
        "exports": len(symbols),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True, choices=("android", "ios", "ohos"))
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--abi")
    parser.add_argument("--contract", type=Path)
    parser.add_argument("--cacert-sha256")
    parser.add_argument("--nm", help="nm that can read the packed library")
    parser.add_argument(
        "--lock",
        type=Path,
        help="plugin native_libs.lock.json that the package must match",
    )
    parser.add_argument(
        "--plugin-root",
        type=Path,
        help="plugin checkout holding assets/cacert.pem, required with --lock",
    )
    args = parser.parse_args(argv)
    try:
        lock = None
        cacert_sha256 = args.cacert_sha256
        if args.lock is not None:
            lock = load_lock(args.lock, args.contract)
            if args.plugin_root is None:
                raise PayloadError("--lock also needs --plugin-root for the CA bundle")
            expected_ca = lock_cacert(lock, args.plugin_root)
            if cacert_sha256 and cacert_sha256.lower() != expected_ca:
                raise PayloadError(
                    f"CA digest {cacert_sha256} != lock CA digest {expected_ca}"
                )
            cacert_sha256 = expected_ca
        facts = check(
            args.platform,
            args.archive,
            args.abi,
            args.contract,
            cacert_sha256,
            args.nm,
            lock,
        )
    except (PayloadError, OSError, json.JSONDecodeError, zipfile.BadZipFile) as error:
        print(f"check_git_payload: {error}", file=sys.stderr)
        return 1
    print(
        f"PASS {args.archive.name}: {facts['entry']} "
        f"({facts['bytes']} bytes, packed {facts['packedSha256'][:12]}), "
        f"CA {facts['cacert']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())