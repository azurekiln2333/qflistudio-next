#!/usr/bin/env node
// Verify a staged desktop companion bundle before an installer consumes it.
//
// Why this exists: Studio ships six desktop packages (windows x64/arm64,
// linux x64/arm64, macos x64/arm64) but only the Windows assistant used to
// carry a Node runtime. A companion bundle is only usable when the Node binary
// and the native `node-pty` addon were built for the *package* architecture —
// not for the machine that produced them. Building the macOS x64 package on an
// Apple Silicon runner is exactly the case that silently ships an arm64
// `pty.node` inside an x64 app: the agent starts, then every terminal session
// fails at runtime, on a user's machine, after release.
//
// This script therefore reads the real binary headers (ELF / Mach-O / PE)
// instead of trusting the build host, the npm log or a filename. No external
// tools (`file`, `lipo`, `dumpbin`) and no network: it must run on every CI OS.
//
// Usage:
//   node companion/tools/verify_companion_bundle.mjs --bundle build/ci-artifacts/qfli-companion-5.0.5-macos-x64
//   node companion/tools/verify_companion_bundle.mjs --bundle <dir> --json
//
// Exit 1 lists every problem it found, each naming the file it inspected.

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

// --- binary architecture readers -------------------------------------------

/** @typedef {'x64'|'arm64'|'ia32'|'unknown'} Arch */

/**
 * Reads the CPU architecture from ELF, Mach-O (incl. fat, both byte orders) or
 * PE headers.
 *
 * Mach-O needs explicit endianness handling: a native little-endian Mach-O file
 * begins with the bytes `cf fa ed fe`, so reading it big-endian yields
 * `0xcffaedfe`, not `0xfeedfacf`. Accepting only the big-endian constants would
 * reject every real macOS Node binary and `pty.node`.
 *
 * @param {string} file
 * @returns {{arch: Arch, format: string}}
 */
function readBinaryArch(file) {
  return readBinaryArchFromBytes(readFileSync(file));
}

/**
 * Architecture from raw header bytes. Split out so unit tests can build headers
 * without shipping real binaries.
 *
 * @param {Uint8Array} bytes
 * @returns {{arch: Arch, format: string}}
 */
function readBinaryArchFromBytes(bytes) {
  const buffer = Buffer.from(bytes.buffer ?? bytes, bytes.byteOffset ?? 0, bytes.byteLength ?? bytes.length);
  if (buffer.length < 32) return { arch: 'unknown', format: 'too-small' };

  // ELF
  if (buffer[0] === 0x7f && buffer[1] === 0x45 && buffer[2] === 0x4c && buffer[3] === 0x46) {
    const littleEndian = buffer[5] === 1;
    const machine = littleEndian ? buffer.readUInt16LE(18) : buffer.readUInt16BE(18);
    const arch = machine === 0x3e ? 'x64' : machine === 0xb7 ? 'arm64' : 'unknown';
    return { arch, format: 'elf' };
  }

  // Mach-O, thin 64-bit, native little-endian (bytes cf fa ed fe).
  if (buffer.readUInt32LE(0) === 0xfeedfacf) {
    const cpuType = buffer.readUInt32LE(4);
    return { arch: machoCpuToArch(cpuType), format: 'macho' };
  }
  // Mach-O, thin 64-bit, byte-swapped (bytes fe ed fa cf).
  if (buffer.readUInt32BE(0) === 0xfeedfacf) {
    const cpuType = buffer.readUInt32BE(4);
    return { arch: machoCpuToArch(cpuType), format: 'macho-swapped' };
  }
  // Mach-O, thin 32-bit, native little-endian (bytes ce fa ed fe).
  if (buffer.readUInt32LE(0) === 0xfeedface) {
    const cpuType = buffer.readUInt32LE(4);
    return { arch: machoCpuToArch(cpuType), format: 'macho32' };
  }
  // Mach-O universal (fat): magic ca fe ba be, or the swapped be ba fe ca.
  if (buffer.readUInt32BE(0) === 0xcafebabe || buffer.readUInt32LE(0) === 0xcafebabe) {
    // The fat header stores nfat_arch and the first slice's cputype in the byte
    // order named by the magic, not by the host.
    const littleEndian = !(buffer[0] === 0xca && buffer[1] === 0xfe && buffer[2] === 0xba && buffer[3] === 0xbe);
    const swap32 = (offset) => (littleEndian ? buffer.readUInt32LE(offset) : buffer.readUInt32BE(offset));
    const archCount = swap32(4);
    if (archCount === 0) return { arch: 'unknown', format: 'macho-fat' };
    return { arch: machoCpuToArch(swap32(8)), format: 'macho-fat' };
  }

  // PE / COFF
  if (buffer[0] === 0x4d && buffer[1] === 0x5a) {
    const peOffset = buffer.readUInt32LE(0x3c);
    if (peOffset + 6 <= buffer.length && buffer.readUInt32BE(peOffset) === 0x50450000) {
      const machine = buffer.readUInt16LE(peOffset + 4);
      const arch = machine === 0x8664 ? 'x64' : machine === 0xaa64 ? 'arm64' : machine === 0x14c ? 'ia32' : 'unknown';
      return { arch, format: 'pe' };
    }
    return { arch: 'unknown', format: 'pe-broken' };
  }

  return { arch: 'unknown', format: 'unknown' };
}

/** Mach-O `cputype` → Studio architecture name. */
function machoCpuToArch(cpuType) {
  if (cpuType === 0x01000007) return 'x64';
  if (cpuType === 0x0100000c) return 'arm64';
  return 'unknown';
}

// --- bundle inspection ------------------------------------------------------

const REQUIRED_FILES = [
  'companion.json',
  'package.json',
  // Provenance of the five synchronised relay files; without it the bundle is
  // not auditable against the relay repository it was copied from.
  'relay-core.json',
  'src/agent/main.ts',
  'src/agent/sidecar.ts',
  'src/shared/pairing.ts',
];

/** Wrappers an installer may copy; at least one must exist per platform. */
const WRAPPERS = { windows: 'start.cmd', posix: 'start.sh' };

/** Files that must never be inside a distributed bundle. */
const FORBIDDEN = [
  /(^|[\\/])agent\.json$/i,
  /(^|[\\/])bootstrap\.json$/i,
  /(^|[\\/])cloudterminal\.bootstrap\.json$/i,
  /(^|[\\/])\.env$/i,
  /\.(jks|keystore|p12|pfx)$/i,
  /(^|[\\/])key\.properties$/i,
  /(^|[\\/])id_rsa$/i,
];

/** @param {string} dir */
function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === '.git') continue;
      walk(full, out);
    } else if (entry.isFile()) {
      out.push(full);
    }
  }
  return out;
}

/**
 * @param {string} bundle
 * @returns {{failures: string[], warnings: string[], info: Record<string, unknown>}}
 */
function verify(bundle) {
  const failures = [];
  const warnings = [];
  const info = {};

  if (!existsSync(bundle) || !statSync(bundle).isDirectory()) {
    return { failures: [`${bundle}: bundle directory does not exist`], warnings, info };
  }

  for (const rel of REQUIRED_FILES) {
    if (!existsSync(join(bundle, rel))) failures.push(`${rel}: required file is missing`);
  }

  // The manifest is what the installer and the app read to know what this
  // bundle contains. It must state the architecture it was built for.
  const manifestPath = join(bundle, 'companion.json');
  /** @type {Record<string, unknown>} */
  let manifest = {};
  if (existsSync(manifestPath)) {
    try {
      manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
    } catch (error) {
      failures.push(`companion.json: not valid JSON (${error.message})`);
    }
    info.manifest = manifest;
    for (const key of ['os', 'arch', 'node_version', 'agent_version']) {
      if (typeof manifest[key] !== 'string' || manifest[key].length === 0) {
        failures.push(`companion.json: missing string field "${key}"`);
      }
    }
    if (manifest.os === 'macos' && typeof manifest.sandboxed === 'undefined') {
      warnings.push('companion.json: macOS bundle does not state "sandboxed" (Studio is sandboxed; document the external launch path)');
    }
  }

  const expectedArch = typeof manifest.arch === 'string' ? manifest.arch : undefined;
  const expectedOs = typeof manifest.os === 'string' ? manifest.os : undefined;

  // Node runtime: `node/node` on POSIX, `node/node.exe` on Windows.
  const nodeCandidates = ['node/node', 'node/node.exe', 'node/bin/node'];
  const nodeBinary = nodeCandidates.map((rel) => join(bundle, rel)).find((full) => existsSync(full));
  if (!nodeBinary) {
    failures.push(`node/: bundled Node runtime is missing (looked for ${nodeCandidates.join(', ')})`);
  } else {
    const { arch, format } = readBinaryArch(nodeBinary);
    info.node = { file: relative(bundle, nodeBinary), arch, format };
    if (expectedArch && arch !== expectedArch) {
      failures.push(`${relative(bundle, nodeBinary)}: Node runtime is ${arch} but the bundle targets ${expectedArch} (${format})`);
    }
  }

  // node-pty: the native addon is the dependency that actually breaks across
  // architectures, so its presence and arch are checked explicitly.
  const ptyRoot = join(bundle, 'node_modules', 'node-pty');
  if (!existsSync(ptyRoot)) {
    failures.push('node_modules/node-pty: missing; the agent cannot open terminal sessions');
  } else {
    const ptyFiles = walk(ptyRoot).filter((file) => file.endsWith('.node'));
    info.nodePty = ptyFiles.map((file) => ({ file: relative(bundle, file), ...readBinaryArch(file) }));
    if (ptyFiles.length === 0) {
      failures.push('node_modules/node-pty: no compiled .node addon found');
    }
    for (const entry of info.nodePty) {
      if (expectedArch && entry.arch !== expectedArch) {
        failures.push(`${entry.file}: native addon is ${entry.arch} but the bundle targets ${expectedArch} (${entry.format})`);
      }
    }
  }

  // Wrapper for the target OS, plus the documented pairing-link output.
  const wrapper = expectedOs === 'windows' ? WRAPPERS.windows : WRAPPERS.posix;
  const wrapperPath = join(bundle, wrapper);
  if (!existsSync(wrapperPath)) {
    failures.push(`${wrapper}: launcher missing for ${expectedOs ?? 'unknown OS'}`);
  } else {
    const text = readFileSync(wrapperPath, 'utf8');
    if (!text.includes('cloudterminal://pair') && !text.includes('--print-link')) {
      warnings.push(`${wrapper}: does not mention the pairing link; confirm the launcher prints cloudterminal://pair for CLI fallback`);
    }
    // Attaching to an already-running companion needs a credential, not just a
    // port. A launcher that publishes only a port would let any local process
    // drive the agent.
    if (!text.includes('--port-file')) {
      failures.push(`${wrapper}: does not pass --port-file; a sandboxed desktop app cannot attach without the published credential`);
    }
    if (/MyNewProjects|_wt[\\/]|\/Users\/[^/]+\/MyNewProjects/.test(text)) {
      failures.push(`${wrapper}: contains an absolute development path`);
    }
  }

  // The attach credential contract has to be stated in the manifest, because
  // the desktop app reads it to know whether a port file alone is enough.
  const attach = manifest.attach;
  if (!attach || typeof attach !== 'object') {
    failures.push('companion.json: missing "attach" block describing the loopback handshake');
  } else {
    const attachRecord = /** @type {Record<string, unknown>} */ (attach);
    if (attachRecord.mode !== 'token') {
      failures.push('companion.json: attach.mode must be "token"; a bare port is not an identity');
    }
    if (typeof attachRecord.port_file !== 'string' || !attachRecord.port_file.endsWith('.json')) {
      failures.push('companion.json: attach.port_file must name the JSON file carrying {port, token}');
    }
    if (attachRecord.file_mode !== '0600') {
      failures.push('companion.json: attach.file_mode must be 0600 (the credential is user-private)');
    }
  }

  // Secrets and machine-local state must never ship.
  for (const file of walk(bundle)) {
    const rel = relative(bundle, file).split(sep).join('/');
    for (const pattern of FORBIDDEN) {
      if (pattern.test(rel)) failures.push(`${rel}: credential or environment file must not be bundled`);
    }
    if (/(^|\/)node_modules\/\.cache\//.test(rel)) failures.push(`${rel}: npm cache must not be bundled`);
  }

  // A runtime port file written by a previous local run must never be staged:
  // it would carry this build host's attach token to every installer.
  for (const rel of ['sidecar.json', 'sidecar.port', 'companion/sidecar.json']) {
    if (existsSync(join(bundle, rel))) {
      failures.push(`${rel}: publish the attach file at runtime, never inside the bundle`);
    }
  }

  // A bundle is only meaningful if its agent can be started from its own dir.
  if (existsSync(join(bundle, 'package.json'))) {
    try {
      const pkg = JSON.parse(readFileSync(join(bundle, 'package.json'), 'utf8'));
      if (pkg.name !== 'cloudterminal-server') {
        failures.push(`package.json: unexpected name ${pkg.name}; the bundled agent must be the companion, not a helper package`);
      }
      info.package = { name: pkg.name, version: pkg.version };
    } catch (error) {
      failures.push(`package.json: not valid JSON (${error.message})`);
    }
  }

  return { failures, warnings, info };
}

// --- cli --------------------------------------------------------------------

function parseArgs(argv) {
  const args = { bundle: '', json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--bundle') args.bundle = argv[++i] ?? '';
    else if (arg === '--json') args.json = true;
    else if (arg === '--help' || arg === '-h') args.help = true;
    else throw new Error(`unknown argument: ${arg}`);
  }
  return args;
}

function main(argv) {
  const args = parseArgs(argv);
  if (args.help || !args.bundle) {
    console.log('Usage: node companion/tools/verify_companion_bundle.mjs --bundle <dir> [--json]');
    return args.help ? 0 : 2;
  }

  const bundleDir = resolve(args.bundle);
  const result = verify(bundleDir);

  if (args.json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    for (const warning of result.warnings) console.warn(`warning: ${warning}`);
    if (result.failures.length > 0) {
      console.error(`${result.failures.length} bundle problem(s) in ${bundleDir}:`);
      for (const failure of result.failures) console.error(`  ${failure}`);
    } else {
      const manifest = result.info.manifest ?? {};
      console.log(
        `bundle ok: ${manifest.os}/${manifest.arch} node ${manifest.node_version} agent ${manifest.agent_version}`,
      );
    }
  }
  return result.failures.length > 0 ? 1 : 0;
}

// Only run the CLI when this file is executed directly.
//
// Without this guard the argument parsing and `process.exit` below run at import
// time, so `verify_companion_bundle.test.mjs` could not statically import
// `verify`: the test process would exit before a single assertion ran.
if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  process.exit(main(process.argv.slice(2)));
}

export { verify, readBinaryArch, readBinaryArchFromBytes, machoCpuToArch, main };
