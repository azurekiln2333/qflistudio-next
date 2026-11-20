"""Regression tests for check_git_payload.py.

The check runs on the staged package: a plugin that resolves but never packages
must fail, and a package whose CA or contract disagrees with the native lock must
fail. The packed library itself is compared by format, ABI and exported symbols,
never by bytes, because packaging strips Android libraries and codesigns iOS
framework binaries.
"""
from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_git_payload as payload  # noqa: E402

COMMIT = "0123456789abcdef0123456789abcdef01234567"
CA_BUNDLE = b"-----BEGIN CERTIFICATE-----\nCA\n-----END CERTIFICATE-----\n"
EXPORTS = ["qg_api_version", "qg_add_all"]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def elf_bytes(machine: int = 183, bits: int = 2) -> bytes:
    """Return a minimal ELF header carrying class and machine."""
    header = bytearray(64)
    header[0:4] = b"\x7fELF"
    header[4] = bits
    header[18:20] = struct.pack("<H", machine)
    return bytes(header)


def macho_bytes(cpu: int = 0x0100000C) -> bytes:
    header = bytearray(32)
    header[0:4] = struct.pack("<I", 0xFEEDFACF)
    header[4:8] = struct.pack("<I", cpu)
    return bytes(header)


def write_contract(root: Path, api: int = 2, exports: list[str] | None = None) -> Path:
    path = root / "tool/ci/native_contract.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"apiVersion": api, "requiredExports": exports or EXPORTS}),
        encoding="utf-8",
    )
    return path


def write_plugin(root: Path, contract: Path, cacert: bytes = CA_BUNDLE) -> Path:
    plugin = root / "plugin"
    (plugin / "assets").mkdir(parents=True)
    (plugin / "assets/cacert.pem").write_bytes(cacert)
    exports = json.loads(contract.read_text(encoding="utf-8")).get("requiredExports", [])
    lock = {
        "schemaVersion": 2,
        "apiVersion": 2,
        "requiredExports": exports,
        "contractSha256": sha256(contract.read_bytes()),
        "source": {"commit": COMMIT},
        "files": [],
    }
    (plugin / "native_libs.lock.json").write_text(json.dumps(lock), encoding="utf-8")
    return plugin


def build_apk(
    archive: Path,
    *,
    library: bytes | None = None,
    cacert: bytes | None = CA_BUNDLE,
    abi: str = "arm64-v8a",
    extra_ca: bool = False,
) -> None:
    with zipfile.ZipFile(archive, "w") as bundle:
        if library is not None:
            bundle.writestr(f"lib/{abi}/libqfli_git.so", library)
        if cacert is not None:
            bundle.writestr("assets/flutter_assets/packages/qfli_git/assets/cacert.pem", cacert)
        if extra_ca:
            bundle.writestr(
                "lib/flutter_assets/packages/qfli_git/assets/cacert.pem",
                b"stale",
            )


class PayloadTests(unittest.TestCase):
    def run_check(self, root: Path, archive: Path, contract: Path, plugin: Path, **kwargs):
        return payload.check(
            kwargs.pop("platform", "android"),
            archive,
            kwargs.pop("abi", "arm64-v8a"),
            contract,
            kwargs.pop("cacert_sha256", None),
            kwargs.pop("nm", None),
            kwargs.pop("lock", None),
        )

    def test_complete_package_passes(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes())
            lock = payload.load_lock(plugin / "native_libs.lock.json", contract)
            facts = self.run_check(
                root,
                archive,
                contract,
                plugin,
                cacert_sha256=sha256(CA_BUNDLE),
                lock=lock,
            )
        self.assertEqual(facts["entry"], "lib/arm64-v8a/libqfli_git.so")
        self.assertEqual(facts["cacert"], sha256(CA_BUNDLE))
        self.assertEqual(len(facts["packedSha256"]), 64)

    def test_missing_library_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=None)
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, archive, contract, plugin)
        self.assertIn("has no lib/arm64-v8a/libqfli_git.so", str(raised.exception))

    def test_empty_library_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=b"")
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, archive, contract, plugin)
        self.assertIn("is empty", str(raised.exception))

    def test_wrong_elf_machine_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes(machine=40))
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, archive, contract, plugin)
        self.assertIn("machine is", str(raised.exception))

    def test_wrong_elf_class_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes(bits=1))
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, archive, contract, plugin)
        self.assertIn("64-bit ELF", str(raised.exception))

    def test_missing_ca_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes(), cacert=None)
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, archive, contract, plugin)
        self.assertIn("CA entries", str(raised.exception))

    def test_wrong_ca_digest_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes(), cacert=b"another bundle\n")
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(
                    root, archive, contract, plugin, cacert_sha256=sha256(CA_BUNDLE)
                )
        self.assertIn("SHA-256 is", str(raised.exception))

    def test_two_ca_entries_fail(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes(), extra_ca=True)
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, archive, contract, plugin)
        self.assertIn("expected one", str(raised.exception))

    def test_missing_export_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes())
            with mock.patch.object(
                payload, "defined_symbols", return_value={"qg_api_version"}
            ):
                with self.assertRaises(payload.PayloadError) as raised:
                    self.run_check(
                        root, archive, contract, plugin, nm="/usr/bin/nm"
                    )
        self.assertIn("lacks required exports: qg_add_all", str(raised.exception))

    def test_abi_is_required_for_mobile_platforms(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes())
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, archive, contract, plugin, abi=None)
        self.assertIn("needs --abi", str(raised.exception))

    def test_missing_archive_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, root / "absent.apk", contract, plugin)
        self.assertIn("Missing package", str(raised.exception))

    def test_contract_without_exports_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = root / "tool/ci/native_contract.json"
            contract.parent.mkdir(parents=True)
            contract.write_text(json.dumps({"apiVersion": 2}), encoding="utf-8")
            plugin = write_plugin(root, contract)
            archive = root / "app.apk"
            build_apk(archive, library=elf_bytes())
            with self.assertRaises(payload.PayloadError) as raised:
                self.run_check(root, archive, contract, plugin)
        self.assertIn("no requiredExports", str(raised.exception))


class IosPayloadTests(unittest.TestCase):
    def test_ios_framework_binary_passes(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.ipa"
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.writestr(
                    "Payload/Runner.app/Frameworks/qfli_git.framework/qfli_git",
                    macho_bytes(),
                )
                bundle.writestr(
                    "Payload/Runner.app/Frameworks/App.framework/flutter_assets/"
                    "packages/qfli_git/assets/cacert.pem",
                    CA_BUNDLE,
                )
            with mock.patch.object(
                payload, "defined_symbols", return_value=set(EXPORTS)
            ):
                facts = payload.check(
                    "ios", archive, None, contract, None, "/usr/bin/nm"
                )
        self.assertEqual(
            facts["entry"], "Payload/Runner.app/Frameworks/qfli_git.framework/qfli_git"
        )

    def test_ios_intel_slice_fails(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            archive = root / "app.ipa"
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.writestr(
                    "Payload/Runner.app/Frameworks/qfli_git.framework/qfli_git",
                    macho_bytes(cpu=0x01000007),
                )
                bundle.writestr(
                    "Payload/Runner.app/Frameworks/App.framework/flutter_assets/"
                    "packages/qfli_git/assets/cacert.pem",
                    CA_BUNDLE,
                )
            with self.assertRaises(payload.PayloadError) as raised:
                payload.check("ios", archive, None, contract, None, None)
        self.assertIn("CPU type", str(raised.exception))


class LockTests(unittest.TestCase):
    def test_lock_contract_digest_must_match(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            lock = json.loads((plugin / "native_libs.lock.json").read_text())
            lock["contractSha256"] = "d" * 64
            (plugin / "native_libs.lock.json").write_text(json.dumps(lock))
            with self.assertRaises(payload.PayloadError) as raised:
                payload.load_lock(plugin / "native_libs.lock.json", contract)
        self.assertIn("different contract", str(raised.exception))

    def test_lock_export_list_must_match(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            lock = json.loads((plugin / "native_libs.lock.json").read_text())
            lock["requiredExports"] = ["qg_api_version"]
            (plugin / "native_libs.lock.json").write_text(json.dumps(lock))
            with self.assertRaises(payload.PayloadError) as raised:
                payload.load_lock(plugin / "native_libs.lock.json", contract)
        self.assertIn("required exports do not match", str(raised.exception))

    def test_legacy_lock_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            lock = json.loads((plugin / "native_libs.lock.json").read_text())
            lock["schemaVersion"] = 1
            (plugin / "native_libs.lock.json").write_text(json.dumps(lock))
            with self.assertRaises(payload.PayloadError) as raised:
                payload.load_lock(plugin / "native_libs.lock.json", contract)
        self.assertIn("not schema 2", str(raised.exception))

    def test_lock_cacert_reads_the_plugin_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            digest = payload.lock_cacert({}, plugin)
        self.assertEqual(digest, sha256(CA_BUNDLE))

    def test_lock_cacert_requires_the_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            contract = write_contract(root)
            plugin = write_plugin(root, contract)
            (plugin / "assets/cacert.pem").unlink()
            with self.assertRaises(payload.PayloadError) as raised:
                payload.lock_cacert({}, plugin)
        self.assertIn("Missing CA bundle", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
