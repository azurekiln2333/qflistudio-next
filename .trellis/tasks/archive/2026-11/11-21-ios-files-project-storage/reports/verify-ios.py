"""Inspect the exact iOS Actions artifact without installing or launching it."""
import hashlib
import io
import json
import plistlib
import subprocess
import urllib.request
from pathlib import Path
from zipfile import ZipFile

artifact_id = 14685796517
expected_sha256 = '042ed4f8538867f79e40ee829a7b5f8d813c6afc512389c267194b357e1e913e'
credential = subprocess.run(
    ['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n',
    capture_output=True, text=True, check=True, timeout=20,
)
fields = dict(line.split('=', 1) for line in credential.stdout.splitlines() if '=' in line)


class PrivateRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, hdrs, newurl):
        redirected = super().redirect_request(req, fp, code, msg, hdrs, newurl)
        if redirected is not None:
            redirected.remove_header('Authorization')
        return redirected


url = f'https://api.github.com/repos/azurekiln2333/qflistudio-next/actions/artifacts/{artifact_id}/zip'
request = urllib.request.Request(url, headers={
    'User-Agent': 'qfli-ios-package-verification',
    'Authorization': 'Bearer ' + fields['password'],
})
with urllib.request.build_opener(PrivateRedirect()).open(request, timeout=45) as response:
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
    'artifact': artifact_id, 'sha256': expected_sha256, 'ipa': ipa,
    'app_commit': build_info['app_commit'], 'core_commit': build_info['core_commit'],
    **{key: config[key] for key in ('CFBundleIdentifier', 'CFBundleDisplayName', 'UIFileSharingEnabled', 'LSSupportsOpeningDocumentsInPlace')},
}
result = json.dumps(report, indent=2)
Path(__file__).with_name('ios-artifact-verification.json').write_text(result + '\n', encoding='utf-8')
print(result)
