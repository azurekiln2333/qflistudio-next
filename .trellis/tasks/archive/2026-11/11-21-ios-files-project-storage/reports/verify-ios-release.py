"""Inspect the published iOS archive without installing or launching it."""
import hashlib
import io
import json
import plistlib
import urllib.request
from pathlib import Path
from zipfile import ZipFile

expected_sha256 = 'e6014ba172208e9e8e707a475c78bebdf1075c47e86ce14e8112cb6961b80bb5'
url = 'https://github.com/azurekiln2333/qflistudio-next/releases/download/v5.0.5-git.6/qflistudio-5.0.5-ios-arm64.zip'
request = urllib.request.Request(url, headers={'User-Agent': 'qfli-ios-package-verification'})
with urllib.request.urlopen(request, timeout=30) as response:
    package = response.read()
assert hashlib.sha256(package).hexdigest() == expected_sha256
with ZipFile(io.BytesIO(package)) as archive:
    build_info = dict(line.split('=', 1) for line in archive.read('BUILD_INFO.txt').decode().splitlines() if '=' in line)
    assert build_info['app_commit'] == '07d8082abaf9d1aabd3f91058ff1430d2097f0c4'
    assert build_info['core_commit'] == '123602be34ab6fa9725bb93f0d3bc27a630c7b44'
    ipa = next(name for name in archive.namelist() if name.endswith('.ipa'))
    with ZipFile(io.BytesIO(archive.read(ipa))) as ios:
        config = plistlib.loads(ios.read('Payload/Runner.app/Info.plist'))
assert config['CFBundleIdentifier'] == 'com.azurekiln.qflistudio'
assert config['CFBundleDisplayName'] == 'QFLIStudioN'
assert config['UIFileSharingEnabled'] is True
assert config['LSSupportsOpeningDocumentsInPlace'] is True
report = {
    'release_tag': 'v5.0.5-git.6', 'sha256': expected_sha256, 'ipa': ipa,
    'app_commit': build_info['app_commit'], 'core_commit': build_info['core_commit'],
    **{key: config[key] for key in ('CFBundleIdentifier', 'CFBundleDisplayName', 'UIFileSharingEnabled', 'LSSupportsOpeningDocumentsInPlace')},
}
result = json.dumps(report, indent=2)
Path(__file__).with_name('ios-release-verification.json').write_text(result + '\n', encoding='utf-8')
print(result)

