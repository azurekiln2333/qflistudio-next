// Unit tests for the companion bundle verifier.
//
// Run in CI: `node --test companion/tools/verify_companion_bundle.test.mjs`
// (no dependencies, runs on every OS with the workflow's Node version).
//
// The header cases are expressed as raw bytes on purpose. A regression here is
// not cosmetic: accepting only big-endian Mach-O magic rejected every real
// macOS Node binary, so the macOS bundle could never pass verification and the
// installer would ship without a companion.

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { readBinaryArchFromBytes, machoCpuToArch, verify } from './verify_companion_bundle.mjs';

const CPU_X64 = 0x01000007;
const CPU_ARM64 = 0x0100000c;

/** @param {number} value */
function u32le(value) {
  const out = Buffer.alloc(4);
  out.writeUInt32LE(value >>> 0, 0);
  return out;
}

/** @param {number} value */
function u32be(value) {
  const out = Buffer.alloc(4);
  out.writeUInt32BE(value >>> 0, 0);
  return out;
}

/** Little-endian (native) 64-bit Mach-O header. */
function machoLe(cpuType) {
  return Buffer.concat([u32le(0xfeedfacf), u32le(cpuType), Buffer.alloc(48)]);
}

/** Big-endian (byte-swapped) 64-bit Mach-O header. */
function machoBe(cpuType) {
  return Buffer.concat([u32be(0xfeedfacf), u32be(cpuType), Buffer.alloc(48)]);
}

/** Universal binary: magic + nfat_arch + first slice cputype. */
function fatMacho(cpuType, { swapped = false } = {}) {
  const magic = swapped ? u32le(0xcafebabe) : u32be(0xcafebabe);
  const count = swapped ? u32le(1) : u32be(1);
  const cputype = swapped ? u32le(cpuType) : u32be(cpuType);
  return Buffer.concat([magic, count, cputype, Buffer.alloc(64)]);
}

function elf(machine, { littleEndian = true } = {}) {
  const buffer = Buffer.alloc(64);
  buffer[0] = 0x7f;
  buffer[1] = 0x45;
  buffer[2] = 0x4c;
  buffer[3] = 0x46;
  buffer[4] = 2; // 64-bit
  buffer[5] = littleEndian ? 1 : 2; // data encoding
  if (littleEndian) buffer.writeUInt16LE(machine, 18);
  else buffer.writeUInt16BE(machine, 18);
  return buffer;
}

function pe(machine) {
  const buffer = Buffer.alloc(128);
  buffer[0] = 0x4d;
  buffer[1] = 0x5a;
  buffer.writeUInt32LE(0x40, 0x3c);
  buffer.writeUInt32BE(0x50450000, 0x40);
  buffer.writeUInt16LE(machine, 0x44);
  return buffer;
}

describe('binary header parsing', () => {
  it('reads native little-endian Mach-O (cf fa ed fe)', () => {
    // Byte order sanity: the first four bytes of a real arm64 Mach-O binary.
    const header = machoLe(CPU_ARM64);
    assert.deepEqual([...header.subarray(0, 4)], [0xcf, 0xfa, 0xed, 0xfe]);
    // Big-endian read of those bytes is 0xcffaedfe — the value the old
    // implementation compared against 0xfeedfacf and therefore rejected.
    assert.equal(header.readUInt32BE(0), 0xcffaedfe);
    assert.deepEqual(readBinaryArchFromBytes(header), { arch: 'arm64', format: 'macho' });
    assert.deepEqual(readBinaryArchFromBytes(machoLe(CPU_X64)), { arch: 'x64', format: 'macho' });
  });

  it('reads byte-swapped Mach-O (fe ed fa cf) with big-endian fields', () => {
    const header = machoBe(CPU_X64);
    assert.deepEqual([...header.subarray(0, 4)], [0xfe, 0xed, 0xfa, 0xcf]);
    assert.deepEqual(readBinaryArchFromBytes(header), { arch: 'x64', format: 'macho-swapped' });
    assert.deepEqual(readBinaryArchFromBytes(machoBe(CPU_ARM64)), { arch: 'arm64', format: 'macho-swapped' });
  });

  it('reads fat Mach-O with its own byte order', () => {
    assert.deepEqual(readBinaryArchFromBytes(fatMacho(CPU_X64)), { arch: 'x64', format: 'macho-fat' });
    assert.deepEqual(readBinaryArchFromBytes(fatMacho(CPU_ARM64)), { arch: 'arm64', format: 'macho-fat' });
    // Swapped fat header (be ba fe ca) stores nfat_arch and cputype little-endian.
    assert.deepEqual(readBinaryArchFromBytes(fatMacho(CPU_X64, { swapped: true })), { arch: 'x64', format: 'macho-fat' });
    assert.deepEqual(readBinaryArchFromBytes(fatMacho(CPU_ARM64, { swapped: true })), { arch: 'arm64', format: 'macho-fat' });
  });

  it('reads ELF in both byte orders', () => {
    assert.deepEqual(readBinaryArchFromBytes(elf(0x3e)), { arch: 'x64', format: 'elf' });
    assert.deepEqual(readBinaryArchFromBytes(elf(0xb7)), { arch: 'arm64', format: 'elf' });
    assert.deepEqual(readBinaryArchFromBytes(elf(0x3e, { littleEndian: false })), { arch: 'x64', format: 'elf' });
  });

  it('reads PE machine types', () => {
    assert.deepEqual(readBinaryArchFromBytes(pe(0x8664)), { arch: 'x64', format: 'pe' });
    assert.deepEqual(readBinaryArchFromBytes(pe(0xaa64)), { arch: 'arm64', format: 'pe' });
  });

  it('reports unknown instead of guessing', () => {
    assert.equal(readBinaryArchFromBytes(Buffer.alloc(8)).arch, 'unknown');
    assert.equal(readBinaryArchFromBytes(Buffer.from('not a binary at all, just text padding')).arch, 'unknown');
    assert.equal(machoCpuToArch(0x00000007), 'unknown');
  });
});

// --- bundle verification ---------------------------------------------------

function stageBundle({ os = 'macos', arch = 'arm64', nodeArch = arch, ptyArch = arch, attach = true } = {}) {
  const root = mkdtempSync(join(tmpdir(), 'companion-bundle-'));
  const bundle = join(root, 'qfli-companion-5.0.5-test');
  mkdirSync(join(bundle, 'node'), { recursive: true });
  mkdirSync(join(bundle, 'src', 'agent'), { recursive: true });
  mkdirSync(join(bundle, 'src', 'shared'), { recursive: true });
  mkdirSync(join(bundle, 'node_modules', 'node-pty', 'build', 'Release'), { recursive: true });

  const manifest = {
    component: 'remote_companion',
    os,
    arch,
    node_version: '24.14.1',
    agent_version: '5.0.5',
    ...(os === 'macos' ? { sandboxed: true } : {}),
    ...(attach
      ? { attach: { mode: 'token', port_file: 'sidecar.json', file_mode: '0600', token_bytes: 24 } }
      : {}),
  };
  writeFileSync(join(bundle, 'companion.json'), JSON.stringify(manifest));
  writeFileSync(join(bundle, 'package.json'), JSON.stringify({ name: 'cloudterminal-server', version: '5.0.5' }));
  writeFileSync(join(bundle, 'relay-core.json'), JSON.stringify({ commit: '0'.repeat(40), files: {} }));
  writeFileSync(join(bundle, 'src/agent/main.ts'), '// agent entry\n');
  writeFileSync(join(bundle, 'src/agent/sidecar.ts'), '// sidecar\n');
  writeFileSync(join(bundle, 'src/shared/pairing.ts'), '// pairing\n');

  const nodeHeader = os === 'windows' ? pe(nodeArch === 'x64' ? 0x8664 : 0xaa64) : machoLe(nodeArch === 'x64' ? CPU_X64 : CPU_ARM64);
  writeFileSync(join(bundle, 'node', os === 'windows' ? 'node.exe' : 'node'), nodeHeader);
  writeFileSync(join(bundle, 'node_modules/node-pty/build/Release/pty.node'), machoLe(ptyArch === 'x64' ? CPU_X64 : CPU_ARM64));

  const launcher = os === 'windows'
    ? '@echo off\r\nrem cloudterminal://pair?...\r\n"%~dp0node\\node.exe" src\\agent\\main.ts --sidecar --port-file "%PORT_FILE%" %*\r\n'
    : '#!/bin/sh\nexec ./node/bin/node src/agent/main.ts --sidecar --port-file "$port" "$@"\n';
  writeFileSync(join(bundle, os === 'windows' ? 'start.cmd' : 'start.sh'), launcher);

  return { root, bundle, cleanup: () => rmSync(root, { recursive: true, force: true }) };
}

describe('bundle verification', () => {
  it('accepts a matching arm64 macOS bundle', () => {
    const staged = stageBundle({ os: 'macos', arch: 'arm64' });
    try {
      const result = verify(staged.bundle);
      assert.deepEqual(result.failures, []);
      assert.equal(result.info.node.arch, 'arm64');
    } finally {
      staged.cleanup();
    }
  });

  it('rejects an arm64 node-pty inside an x64 bundle (Apple Silicon building macos x64)', () => {
    const staged = stageBundle({ os: 'macos', arch: 'x64', nodeArch: 'x64', ptyArch: 'arm64' });
    try {
      const result = verify(staged.bundle);
      assert.equal(result.failures.length, 1);
      assert.match(result.failures[0], /native addon is arm64 but the bundle targets x64/);
    } finally {
      staged.cleanup();
    }
  });

  it('rejects a Node runtime built for the wrong architecture', () => {
    const staged = stageBundle({ os: 'linux', arch: 'x64', nodeArch: 'arm64' });
    try {
      const result = verify(staged.bundle);
      assert.ok(result.failures.some((failure) => /Node runtime is arm64/.test(failure)));
    } finally {
      staged.cleanup();
    }
  });

  it('accepts a windows x64 bundle', () => {
    const staged = stageBundle({ os: 'windows', arch: 'x64', nodeArch: 'x64', ptyArch: 'x64' });
    try {
      assert.deepEqual(verify(staged.bundle).failures, []);
    } finally {
      staged.cleanup();
    }
  });

  it('requires relay-core.json for provenance', () => {
    const staged = stageBundle();
    try {
      rmSync(join(staged.bundle, 'relay-core.json'));
      const result = verify(staged.bundle);
      assert.ok(result.failures.includes('relay-core.json: required file is missing'));
    } finally {
      staged.cleanup();
    }
  });

  it('requires the attach credential contract instead of a bare port', () => {
    const staged = stageBundle({ attach: false });
    try {
      const result = verify(staged.bundle);
      assert.ok(result.failures.some((failure) => /missing "attach" block/.test(failure)));
    } finally {
      staged.cleanup();
    }
  });

  it('refuses to ship a credential or a published attach file', () => {
    const staged = stageBundle();
    try {
      writeFileSync(join(staged.bundle, 'agent.json'), '{"agentId":"a_x"}');
      writeFileSync(join(staged.bundle, 'sidecar.json'), '{"port":1,"token":"t"}');
      const result = verify(staged.bundle);
      assert.ok(result.failures.some((failure) => /agent\.json: credential/.test(failure)));
      assert.ok(result.failures.some((failure) => /sidecar\.json: publish the attach file at runtime/.test(failure)));
    } finally {
      staged.cleanup();
    }
  });
});
