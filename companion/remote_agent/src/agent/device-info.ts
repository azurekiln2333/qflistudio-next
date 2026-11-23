// Device information the phone shows in the Agents details view.
//
// The wire fields are `hostName`, `os` and `osVersion`; the phone mirrors them
// in `HarnessDeviceInfo`. `os` is a lowercase short name, never a Node
// runtime value such as `win32` or `darwin`.

import { hostname, release, version as osVersionText } from 'node:os';
import { readFile } from 'node:fs/promises';

export type DeviceOs = 'windows' | 'macos' | 'linux' | 'other';

export type DeviceInfo = {
  hostName: string;
  os: DeviceOs;
  osVersion: string;
};

/** Map a Node platform value to the short name the phone understands. */
export function mapPlatform(platform: NodeJS.Platform): DeviceOs {
  switch (platform) {
    case 'win32':
      return 'windows';
    case 'darwin':
      return 'macos';
    case 'linux':
      return 'linux';
    default:
      return 'other';
  }
}

/**
 * Human-readable system version.
 *
 * Windows keeps the build number, macOS maps the Darwin release to a product
 * name, Linux reads `PRETTY_NAME`. Every branch falls back to the raw release
 * string instead of inventing a name.
 */
export async function formatOsVersion(
  platform: NodeJS.Platform,
  deps: {
    release?: () => string;
    version?: () => string;
    readOsRelease?: () => Promise<string | null>;
  } = {},
): Promise<string> {
  const releaseText = (deps.release ?? release)();
  const versionValue = (deps.version ?? osVersionText)();
  switch (platform) {
    case 'win32': {
      // `os.version()` is `Microsoft Windows 11 Home` on a real host. Keep
      // everything after the prefix: the edition (`Home`, `Pro`) is what a
      // user recognises, so cutting at the first space loses it.
      const product = versionValue.match(/^Microsoft Windows (.+)$/)?.[1];
      return product ? `Windows ${product.trim()} (${releaseText})` : releaseText;
    }
    case 'darwin':
      return macOSName(releaseText) ?? releaseText;
    case 'linux': {
      const name = await readLinuxPrettyName(deps.readOsRelease);
      return name ?? releaseText;
    }
    default:
      return releaseText;
  }
}

/**
 * Map a Darwin kernel release to a product name.
 *
 * Only the major version matters: Darwin 24 is macOS 15. An unknown major
 * returns null so the caller can print the raw release.
 */
export function macOSName(darwinRelease: string): string | null {
  const major = Number.parseInt(darwinRelease.split('.')[0] ?? '', 10);
  if (!Number.isFinite(major)) return null;
  const table: Record<number, number> = {
    24: 15,
    23: 14,
    22: 13,
    21: 12,
    20: 11,
    19: 10.15,
  };
  const product = table[major];
  return product === undefined ? null : `macOS ${product}`;
}

/** `PRETTY_NAME` from /etc/os-release, or null when it is not readable. */
export async function readLinuxPrettyName(
  read: () => Promise<string | null> = () => readFile('/etc/os-release', 'utf8').catch(() => null),
): Promise<string | null> {
  const text = await read().catch(() => null);
  if (!text) return null;
  for (const line of text.split('\n')) {
    const match = line.match(/^PRETTY_NAME=(.*)$/);
    if (!match) continue;
    const raw = match[1] ?? '';
    const value = raw.trim().replace(/^"(.*)"$/, '$1');
    if (value) return value;
  }
  return null;
}

/** Collect the three fields the `info` reply carries. */
export async function collectDeviceInfo(
  platform: NodeJS.Platform = process.platform,
  name: string = hostname(),
): Promise<DeviceInfo> {
  return {
    hostName: name,
    os: mapPlatform(platform),
    osVersion: await formatOsVersion(platform),
  };
}
