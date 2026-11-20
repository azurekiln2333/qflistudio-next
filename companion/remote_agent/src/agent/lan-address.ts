import { networkInterfaces } from 'node:os';

/** Phone-visible address; loopback is only for the agent's own relay link. */
export function lanAddress(): string | undefined {
  for (const addresses of Object.values(networkInterfaces())) {
    for (const address of addresses ?? []) {
      if (address.family === 'IPv4' && !address.internal) return address.address;
    }
  }
  return undefined;
}
