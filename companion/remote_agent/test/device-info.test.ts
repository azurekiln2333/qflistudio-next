import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  collectDeviceInfo,
  formatOsVersion,
  macOSName,
  mapPlatform,
  readLinuxPrettyName,
} from '../src/agent/device-info.ts';

test('mapPlatform returns the short names the phone understands', () => {
  assert.equal(mapPlatform('win32'), 'windows');
  assert.equal(mapPlatform('darwin'), 'macos');
  assert.equal(mapPlatform('linux'), 'linux');
  assert.equal(mapPlatform('freebsd'), 'other');
});

test('mapPlatform never returns a runtime value', () => {
  for (const platform of ['win32', 'darwin', 'linux', 'aix', 'openbsd'] as NodeJS.Platform[]) {
    const value = mapPlatform(platform);
    assert.ok(['windows', 'macos', 'linux', 'other'].includes(value), value);
  }
});

test('macOSName maps known Darwin majors and rejects the rest', () => {
  assert.equal(macOSName('24.1.0'), 'macOS 15');
  assert.equal(macOSName('23.6.0'), 'macOS 14');
  assert.equal(macOSName('19.6.0'), 'macOS 10.15');
  assert.equal(macOSName('99.0.0'), null);
  assert.equal(macOSName('not-a-version'), null);
});

test('formatOsVersion keeps the Windows build number', async () => {
  const text = await formatOsVersion('win32', {
    release: () => '10.0.22631',
    version: () => 'Microsoft Windows 11 Home',
  });
  assert.equal(text, 'Windows 11 Home (10.0.22631)');
});

test('formatOsVersion falls back to the raw release for Windows', async () => {
  const text = await formatOsVersion('win32', {
    release: () => '10.0.19045',
    version: () => 'unexpected',
  });
  assert.equal(text, '10.0.19045');
});

test('formatOsVersion uses the macOS product name', async () => {
  const text = await formatOsVersion('darwin', {
    release: () => '24.1.0',
    version: () => 'Darwin Kernel Version 24.1.0',
  });
  assert.equal(text, 'macOS 15');
});

test('formatOsVersion falls back to the Darwin release when unmapped', async () => {
  const text = await formatOsVersion('darwin', {
    release: () => '99.1.0',
    version: () => 'Darwin Kernel Version 99.1.0',
  });
  assert.equal(text, '99.1.0');
});

test('formatOsVersion reads PRETTY_NAME on Linux', async () => {
  const text = await formatOsVersion('linux', {
    release: () => '6.8.0-45-generic',
    version: () => '#45-Ubuntu SMP',
    readOsRelease: async () => 'NAME="Ubuntu"\nPRETTY_NAME="Ubuntu 24.04.1 LTS"\nID=ubuntu\n',
  });
  assert.equal(text, 'Ubuntu 24.04.1 LTS');
});

test('formatOsVersion falls back to the kernel release on Linux', async () => {
  const text = await formatOsVersion('linux', {
    release: () => '6.8.0-45-generic',
    version: () => '#45',
    readOsRelease: async () => null,
  });
  assert.equal(text, '6.8.0-45-generic');
});

test('readLinuxPrettyName tolerates a missing file and unquoted values', async () => {
  assert.equal(await readLinuxPrettyName(async () => null), null);
  assert.equal(await readLinuxPrettyName(async () => 'PRETTY_NAME=Debian 12\n'), 'Debian 12');
  assert.equal(await readLinuxPrettyName(async () => 'NAME=Debian\n'), null);
  assert.equal(await readLinuxPrettyName(async () => 'PRETTY_NAME=""\n'), null);
});

test('collectDeviceInfo fills all three fields', async () => {
  const info = await collectDeviceInfo('linux', 'workstation');
  assert.equal(info.hostName, 'workstation');
  assert.equal(info.os, 'linux');
  assert.equal(typeof info.osVersion, 'string');
  assert.ok(info.osVersion.length > 0);
});
