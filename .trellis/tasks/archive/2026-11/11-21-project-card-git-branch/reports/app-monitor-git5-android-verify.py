"""Inspect one released Android ZIP as data without extracting or executing it."""
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).parent
APP = '23b81a4abf33c9cec73490ba498bae5110acd587'
CORE = '0f18c3692791e66aa8cb74e71f49ea52469b7295'
PLUGIN = '53ad359159258706d4c242e70a2db0e1d075dabc'
NATIVE = 'd002bd3e9febb478758b75b6670a24ba8a3c610c'
release = json.loads((ROOT / 'app-monitor-git5-release.json').read_text(encoding='utf-8'))
asset = next(item for item in release['assets'] if item['name'] == 'qflistudio-5.0.5-android-arm64-v8a.zip')
archive = ROOT / 'app-monitor-git5-android-arm64-v8a.zip'
if not archive.exists():
    request = urllib.request.Request(asset['browser_download_url'], headers={
        'User-Agent': 'qfli-release-android-verification',
    })
    with urllib.request.urlopen(request, timeout=90) as response, archive.open('wb') as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
assert archive.stat().st_size == asset['size']
hasher = hashlib.sha256()
with archive.open('rb') as source:
    while chunk := source.read(1024 * 1024):
        hasher.update(chunk)
assert asset['digest'] == 'sha256:' + hasher.hexdigest()

with zipfile.ZipFile(archive) as package:
    names = package.namelist()
    assert 'BUILD_INFO.txt' in names and 'SHA256SUMS' in names
    info_text = package.read('BUILD_INFO.txt').decode('utf-8')
    (ROOT / 'app-monitor-git5-android-BUILD_INFO.txt').write_text(info_text, encoding='utf-8')
    facts = dict(line.split('=', 1) for line in info_text.splitlines() if '=' in line)
    expected = {
        'target': 'qflistudio-5.0.5-android-arm64-v8a',
        'app_version': '5.0.5', 'app_commit': APP, 'core_commit': CORE,
        'build_mode': 'release', 'plugin': 'qfli_git',
        'plugin_commit': PLUGIN, 'plugin_native_source': NATIVE,
        'plugin_native_api_version': '2', 'plugin_pending': '0',
        'device_validation': 'none',
    }
    for key, value in expected.items():
        assert facts.get(key) == value, (key, facts.get(key), value)
    for line in package.read('SHA256SUMS').decode('utf-8').splitlines():
        digest, name = line.split(maxsplit=1)
        name = name.strip().lstrip('*')
        if name.startswith('./'):
            name = name[2:]
        assert hashlib.sha256(package.read(name)).hexdigest() == digest, name
    apks = [name for name in names if name.endswith('.apk')]
    assert len(apks) == 1
    apk_name = apks[0]
    with zipfile.ZipFile(io.BytesIO(package.read(apk_name))) as apk:
        apk_names = apk.namelist()
        required = {
            'AndroidManifest.xml', 'classes.dex',
            'lib/arm64-v8a/libapp.so', 'lib/arm64-v8a/libflutter.so',
            'lib/arm64-v8a/libqfli_git.so',
        }
        assert required.issubset(apk_names)
        abis = {name.split('/')[1] for name in apk_names if name.startswith('lib/') and name.endswith('.so')}
        assert abis == {'arm64-v8a'}
        native = apk.read('lib/arm64-v8a/libqfli_git.so')
        assert native[:4] == bytes([127]) + b'ELF' and native[4] == 2
        assert int.from_bytes(native[18:20], 'little') == 183
        ca_names = [name for name in apk_names if name.endswith('packages/qfli_git/assets/cacert.pem')]
        assert len(ca_names) == 1
        assert hashlib.sha256(apk.read(ca_names[0])).hexdigest() == facts['plugin_cacert_sha256']
        apk_facts = {'apk_entry_count': len(apk_names), 'abis': sorted(abis), 'native_git_present': True, 'native_elf_aarch64': True, 'ca_entry': ca_names[0], 'ca_digest_verified': True}

report = {
    'release_tag': 'v5.0.5-git.5', 'archive': archive.name,
    'asset_id': asset['id'], 'asset_size': asset['size'],
    'download_sha256': hasher.hexdigest(), 'api_digest_verified': True,
    'inner_checksums_verified': True, 'apk_name': apk_name,
    'build_info': facts, 'apk': apk_facts,
    'verification_scope': 'Archive and APK file inspection only. No extraction, execution, installation or device validation.',
}
(ROOT / 'app-monitor-git5-android-verification.json').write_text(
    json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8',
)
print(json.dumps(report, ensure_ascii=False, indent=2))
