#!/usr/bin/env node
import { pathToFileURL } from 'node:url';

export const BLOCK_MARKER = 'AZUREKILN_MODERATION_TEST_BLOCK';
const variants = [
  ['marker', BLOCK_MARKER],
  ['lowercase', BLOCK_MARKER.toLowerCase()],
  ['fullwidth', BLOCK_MARKER.replace(/[A-Z_]/g, c => String.fromCharCode(c.charCodeAt(0) + 0xfee0))],
  ['separators', [...BLOCK_MARKER].join(' ·\u200b')],
  ['traditional', '買 賣 軍 用 槍 支'],
  ['drug-separators', '海 洛·因'],
];

function baseUrl(value) {
  if (!value) return null;
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) {
    throw new Error('Base URLs must be HTTP(S), without credentials, query, or fragment');
  }
  return url.href.replace(/\/+$/, '');
}

function integer(value, fallback, min, max) {
  const result = value === undefined || value === '' ? fallback : Number(value);
  if (!Number.isInteger(result) || result < min || result > max) throw new Error(`Expected an integer between ${min} and ${max}`);
  return result;
}

export function optionsFrom(argv = [], env = process.env) {
  const flags = {};
  const values = new Set(['--qfli', '--moderation', '--timeout-ms', '--max-rate-requests']);
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (values.has(flag)) {
      if (!argv[i + 1] || argv[i + 1].startsWith('--')) throw new Error(`Missing value for ${flag}`);
      flags[flag] = argv[++i];
    } else if (['--strict', '--allow-rate', '--help'].includes(flag)) flags[flag] = true;
    else throw new Error('Unknown argument; use --help');
  }
  if (flags['--help']) return { help: true };
  const options = {
    qfli: baseUrl(flags['--qfli'] || env.SMOKE_QFLI_BASE_URL),
    moderation: baseUrl(flags['--moderation'] || env.MODERATION_BASE_URL),
    appId: env.MODERATION_APP_ID || '',
    apiKey: env.MODERATION_API_KEY || '',
    unverifiedToken: env.SMOKE_UNVERIFIED_TOKEN || '',
    rateToken: env.SMOKE_RATE_TOKEN || '',
    zoneId: env.SMOKE_ZONE_ID || '',
    strict: flags['--strict'] === true,
    allowRate: flags['--allow-rate'] === true,
    timeoutMs: integer(flags['--timeout-ms'], 5000, 100, 30000),
    maxRateRequests: integer(flags['--max-rate-requests'], 5, 2, 101),
  };
  if (!options.qfli && !options.moderation) throw new Error('Supply --qfli or --moderation');
  return options;
}

// Keep error bodies, credentials, and upstream exception messages out of output.
export async function requestJson(url, { method = 'GET', headers = {}, body, timeoutMs = 5000, fetchImpl = fetch } = {}) {
  let response;
  try {
    response = await fetchImpl(url, {
      method,
      headers: { accept: 'application/json', ...headers, ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
      body: body === undefined ? undefined : JSON.stringify(body),
      redirect: 'error',
      signal: AbortSignal.timeout(timeoutMs),
    });
    const json = await response.json();
    return { status: response.status, json };
  } catch {
    throw new Error(response ? 'Response was incomplete or not JSON' : 'Request failed or timed out');
  }
}

function expect(result, status, condition, description) {
  if (result.status !== status || !condition(result.json)) throw new Error(`${description}; received HTTP ${result.status}`);
  return `HTTP ${status}`;
}

export async function runSmoke(options, { fetchImpl = fetch, report = () => {} } = {}) {
  const cases = [];
  const call = (base, path, config = {}) => requestJson(`${base}${path}`, { timeoutMs: options.timeoutMs, fetchImpl, ...config });
  const moderationHeaders = { 'X-App-Id': options.appId, authorization: `Bearer ${options.apiKey}` };
  const accountHeaders = token => ({ authorization: `Bearer ${token}`, 'X-Client-Platform': 'web/compliance-smoke' });
  const textCheck = text => call(options.moderation, '/v1/text/check', {
    method: 'POST', headers: moderationHeaders, body: { scene: 'community.post.title', text },
  });
  async function probe(name, available, work, missing) {
    let entry;
    if (!available) entry = { name, status: 'skip', detail: missing };
    else {
      try { entry = { name, status: 'pass', detail: await work() }; }
      catch (error) { entry = { name, status: 'fail', detail: error.message }; }
    }
    cases.push(entry);
    report(entry);
  }
  await probe('qfli.health', options.qfli, async () => {
    const result = await call(options.qfli, '/api/health');
    return expect(result, 200, body => body?.ok === true, 'Expected a healthy QFLI database');
  }, 'QFLI base URL missing');
  await probe('moderation.health', options.moderation, async () => {
    const result = await call(options.moderation, '/healthz');
    return expect(result, 200, body => body?.status === 'ok', 'Expected a healthy moderation database');
  }, 'Moderation base URL missing');
  const canCheck = options.moderation && options.appId && options.apiKey;
  let markerBlocked = false;
  for (const [name, text] of variants) {
    await probe(`text.${name}`, canCheck, async () => {
      const result = await textCheck(text);
      const detail = expect(result, 200, body => body?.decision === 'block', 'Expected decision block');
      if (name === 'marker') markerBlocked = true;
      return `${detail}, block`;
    }, 'Moderation URL or app credentials missing');
  }
  for (const [name, path] of [
    ['community', '/api/posts'], ['cloud', '/api/cloud/projects'],
    ['terminal', '/api/terminal/pwd'], ['ai', '/api/ai/models'], ['sql', '/api/sql/databases'],
  ]) {
    await probe(`realname.${name}`, options.qfli && options.unverifiedToken, async () => {
      for (const variant of [path, `${path}?compliance_smoke=1`, path.toUpperCase()]) {
        const result = await call(options.qfli, variant, { headers: accountHeaders(options.unverifiedToken) });
        expect(result, 403, body => body?.errorKey === 'realname.required', 'Expected realname.required for every path variant');
      }
      return 'HTTP 403 across canonical, query, and uppercase paths';
    }, 'QFLI URL or dedicated unverified test token missing');
  }
  await probe('publish.rate', options.qfli && options.rateToken && options.allowRate && canCheck, async () => {
    if (!markerBlocked) throw new Error('Rate probe refused: marker preflight did not block');
    let zoneId = options.zoneId;
    if (!zoneId) {
      const zones = await call(options.qfli, '/api/zones', { headers: accountHeaders(options.rateToken) });
      expect(zones, 200, body => typeof body?.items?.[0]?.id === 'string', 'Expected a zone for the verified test account');
      zoneId = zones.json.items[0].id;
    }
    for (let attempt = 1; attempt <= options.maxRateRequests; attempt++) {
      const result = await call(options.qfli, '/api/posts', {
        method: 'POST', headers: accountHeaders(options.rateToken),
        body: { type: 'discussion', zoneId, title: BLOCK_MARKER, content: BLOCK_MARKER, tags: [] },
      });
      if (result.status === 429) {
        expect(result, 429, body => body?.errorKey === 'rate.limited'
          && Number.isFinite(body.retryAfter) && body.retryAfter > 0, 'Expected rate.limited and retryAfter');
        return `HTTP 429 after ${attempt} test requests`;
      }
      // Stop immediately on any successful or pending publication.
      expect(result, 422, body => body?.errorKey === 'moderation.blocked', 'Expected blocked test content before the rate limit');
    }
    throw new Error('Rate limit not reached within the configured request budget');
  }, 'Requires QFLI URL, app credentials, verified test token, and --allow-rate');
  const counts = Object.fromEntries(['pass', 'fail', 'skip'].map(status => [status, cases.filter(item => item.status === status).length]));
  return { cases, counts, ok: counts.fail === 0 && (!options.strict || counts.skip === 0) };
}

export async function main(argv = process.argv.slice(2), env = process.env) {
  try {
    const options = optionsFrom(argv, env);
    if (options.help) {
      console.log('node scripts/compliance/smoke.mjs --qfli URL --moderation URL [--strict] [--allow-rate] [--max-rate-requests 5] [--timeout-ms 5000]');
      console.log('Credentials: MODERATION_APP_ID, MODERATION_API_KEY, SMOKE_UNVERIFIED_TOKEN, SMOKE_RATE_TOKEN; optional SMOKE_ZONE_ID.');
      return 0;
    }
    const result = await runSmoke(options, { report: item => console.log(JSON.stringify(item)) });
    console.log(JSON.stringify({ summary: result.counts, ok: result.ok, strict: options.strict }));
    return result.ok ? 0 : 1;
  } catch (error) {
    // Configuration errors are fixed strings; never echo supplied arguments.
    console.error(JSON.stringify({ error: error instanceof TypeError ? 'Invalid base URL' : error.message }));
    return 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) process.exitCode = await main();
