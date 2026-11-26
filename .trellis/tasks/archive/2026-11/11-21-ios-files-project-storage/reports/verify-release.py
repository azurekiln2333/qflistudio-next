"""Read-only release and checksum verification; never execute an artifact."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request

ROOT = Path(__file__).parent
API = 'https://api.github.com/repos/azurekiln2333/qflistudio-next/'
TAG = 'v5.0.5-git.6'
APP = '07d8082abaf9d1aabd3f91058ff1430d2097f0c4'
CORE = '123602be34ab6fa9725bb93f0d3bc27a630c7b44'
RUN = 44851658777

credential = subprocess.run(
    ['git', 'credential', 'fill'],
    input='protocol=https\nhost=github.com\n\n',
    text=True, capture_output=True, check=True, timeout=30,
)
fields = dict(row.split('=', 1) for row in credential.stdout.splitlines() if '=' in row)
token = fields.get('password')
if not token:
    raise SystemExit('GitHub credential is unavailable')

class PrivateRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, hdrs, newurl):
        redirected = super().redirect_request(req, fp, code, msg, hdrs, newurl)
        if redirected is not None:
            redirected.remove_header('Authorization')
        return redirected

opener = urllib.request.build_opener(PrivateRedirect())

def api_get(endpoint):
    request = urllib.request.Request(API + endpoint, headers={
        'User-Agent': 'qfli-release-asset-verification',
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer ' + token,
    })
    with opener.open(request, timeout=60) as response:
        return json.load(response)

release = api_get('releases/tags/' + TAG)
(ROOT / 'app-monitor-git6-release.json').write_text(
    json.dumps(release, ensure_ascii=False, indent=2), encoding='utf-8',
)
assert release['tag_name'] == TAG
assert release['draft'] is False
assert release['prerelease'] is True
assert APP in release['body'] and CORE in release['body']
assert str(RUN) in release['body']

ref = api_get('git/ref/tags/' + TAG)['object']
if ref['type'] == 'tag':
    ref = api_get('git/tags/' + ref['sha'])['object']
assert ref['type'] == 'commit' and ref['sha'] == APP

workflow = api_get('contents/.github/workflows/app-installers.yml?ref=' + TAG)
workflow_text = base64.b64decode(workflow['content']).decode('utf-8')
assert 'CORE_REF: "' + CORE + '"' in workflow_text
assert 'JAVA_REF: "60d97c783f29da767fafe503980812101f6aa61f"' in workflow_text

assets = release['assets']
assert len(assets) == 13
assert len({asset['name'] for asset in assets}) == 13
assert all(asset['state'] == 'uploaded' and asset['size'] > 0 for asset in assets)
manifest_asset = next(asset for asset in assets if asset['name'] == 'SHA256SUMS')
request = urllib.request.Request(manifest_asset['browser_download_url'], headers={
    'User-Agent': 'qfli-release-asset-verification',
})
with opener.open(request, timeout=60) as response:
    manifest_bytes = response.read()
(ROOT / 'app-monitor-git6-SHA256SUMS').write_bytes(manifest_bytes)
assert manifest_asset['digest'] == 'sha256:' + hashlib.sha256(manifest_bytes).hexdigest()
manifest = {}
for line in manifest_bytes.decode('utf-8').splitlines():
    digest, name = line.split(maxsplit=1)
    name = name.strip().lstrip('*')
    if name.startswith('./'):
        name = name[2:]
    assert len(digest) == 64 and name not in manifest
    manifest[name] = digest
zips = [asset for asset in assets if asset['name'].endswith('.zip')]
assert len(zips) == 12
targets = {
    'windows-x64', 'windows-arm64', 'linux-x64', 'linux-arm64',
    'macos-x86_64', 'macos-arm64', 'ios-arm64', 'android-x86_64',
    'android-armeabi-v7a', 'android-arm64-v8a', 'ohos-arm64',
}
expected_zips = {f'qflistudio-5.0.5-{target}.zip' for target in targets}
expected_zips.add('qfli-remote-assistant-5.0.5-windows-x64.zip')
assert {asset['name'] for asset in zips} == expected_zips
assert set(manifest) == {asset['name'] for asset in zips}
for asset in zips:
    assert asset['digest'] == 'sha256:' + manifest[asset['name']], asset['name']

report = {
    'tag': TAG, 'run': RUN, 'release_id': release['id'],
    'release_url': release['html_url'], 'published_at': release['published_at'],
    'app_commit': APP, 'core_commit': CORE,
    'tag_resolves_to_app': True, 'workflow_core_pin_verified': True,
    'java_pin_preserved': True, 'release_body_pins_verified': True,
    'asset_count': len(assets), 'zip_count': len(zips),
    'manifest_api_digest_verified': True, 'all_zip_api_digests_match_manifest': True,
    'verification_scope': 'Release API, exact tagged workflow and published checksum manifest. No installer execution or device validation.',
    'assets': [{key: asset.get(key) for key in ('id', 'name', 'size', 'digest', 'browser_download_url')} for asset in assets],
}
(ROOT / 'app-monitor-git6-verification.json').write_text(
    json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8',
)
print(json.dumps({key: value for key, value in report.items() if key != 'assets'}, ensure_ascii=False, indent=2))

