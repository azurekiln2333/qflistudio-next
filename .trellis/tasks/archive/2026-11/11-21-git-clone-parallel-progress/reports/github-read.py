"""Read GitHub evidence; use Windows TLS for signed log/artifact redirects."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
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
    ['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n',
    text=True, capture_output=True, check=True, timeout=30,
)
fields = dict(row.split('=', 1) for row in credential.stdout.splitlines() if '=' in row)
token = fields.get('password')
if not token:
    raise SystemExit('GitHub credential is unavailable')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


url = f'https://api.github.com/repos/azurekiln2333/{args.repo}/{args.endpoint}'
request = urllib.request.Request(url, headers={
    'User-Agent': 'qfli-release-evidence',
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer ' + token,
})
try:
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=60) as response:
        data = response.read()
except urllib.error.HTTPError as error:
    redirect = error.headers.get('Location')
    if error.code not in (301, 302, 303, 307, 308) or not redirect:
        raise SystemExit(f'GitHub returned HTTP {error.code}') from None
    if urllib.parse.urlsplit(redirect).scheme != 'https':
        raise SystemExit('GitHub redirect is not HTTPS')
    # No authorization header reaches the signed storage endpoint. Capture all
    # subprocess output so signed query parameters cannot appear in diagnostics.
    # A retried curl response written to stdout can retain a failed partial
    # body before the successful ZIP. Give each attempt its own output file.
    with tempfile.TemporaryDirectory(prefix='qfli-github-evidence-') as temporary:
        for attempt in range(3):
            destination = Path(temporary) / f'download-{attempt}'
            fetched = subprocess.run(
                ['curl.exe', '--fail', '--location', '--silent', '--show-error',
                 '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '15',
                 '--max-time', '60', '--output', str(destination), redirect],
                capture_output=True, timeout=65,
            )
            if fetched.returncode == 0:
                data = destination.read_bytes()
                break
        else:
            raise SystemExit(f'Signed GitHub download failed (curl {fetched.returncode})')
except urllib.error.URLError:
    raise SystemExit('GitHub API request failed') from None

if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    print(f'Saved {len(data)} bytes to {args.output}')
else:
    print(json.dumps(json.loads(data), ensure_ascii=False, indent=2))
