"""Read release CI logs using existing Git credentials only in memory."""
import argparse
import json
from pathlib import Path
import subprocess
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('repo', choices=['qflistudio-core', 'qflistudio-next', 'qflistudio-java'])
parser.add_argument('endpoint')
parser.add_argument('--output')
args = parser.parse_args()
if '..' in args.endpoint or args.endpoint.startswith('/'):
    raise SystemExit('Invalid endpoint')
credential = subprocess.run(
    ['git', 'credential', 'fill'],
    input='protocol=https\nhost=github.com\n\n', text=True,
    capture_output=True, check=True,
)
fields = dict(line.split('=', 1) for line in credential.stdout.splitlines() if '=' in line)
token = fields.get('password')
if not token:
    raise SystemExit('GitHub credential is unavailable')
headers = {'User-Agent': 'qfli-release-review', 'Accept': 'application/vnd.github+json', 'Authorization': 'Bearer ' + token}

class PrivateRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, hdrs, newurl):
        redirected = super().redirect_request(req, fp, code, msg, hdrs, newurl)
        if redirected is not None:
            redirected.remove_header('Authorization')
        return redirected

url = f'https://api.github.com/repos/azurekiln2333/{args.repo}/{args.endpoint}'
with urllib.request.build_opener(PrivateRedirect()).open(urllib.request.Request(url, headers=headers), timeout=60) as response:
    data = response.read()
if args.output:
    target = Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f'Saved {len(data)} bytes to {target}')
else:
    print(json.dumps(json.loads(data), indent=2))
