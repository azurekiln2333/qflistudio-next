"""Read GitHub release evidence using the existing credential only in memory."""

import argparse
import json
from pathlib import Path
import subprocess
import urllib.error
import urllib.parse
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('repo', choices=['qflistudio-git', 'qflistudio-core', 'qflistudio-next'])
parser.add_argument('endpoint')
parser.add_argument('--output', type=Path)
args = parser.parse_args()
if '..' in args.endpoint or args.endpoint.startswith('/'):
    raise SystemExit('Invalid repository endpoint')

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


url = f'https://api.github.com/repos/azurekiln2333/{args.repo}/{args.endpoint}'
request = urllib.request.Request(url, headers={
    'User-Agent': 'qfli-git-release-review',
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer ' + token,
})
try:
    with urllib.request.build_opener(PrivateRedirect()).open(request, timeout=60) as response:
        data = response.read()
except urllib.error.HTTPError as error:
    raise SystemExit(f'GitHub returned HTTP {error.code}') from None
except urllib.error.URLError:
    raise SystemExit('GitHub request failed') from None

if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    print(f'Saved {len(data)} bytes to {args.output}')
else:
    print(json.dumps(json.loads(data), ensure_ascii=False, indent=2))
