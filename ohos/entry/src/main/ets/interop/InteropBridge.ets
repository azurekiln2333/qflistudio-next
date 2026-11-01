/*
 * Shared state for the interop bridge ability.
 *
 * StudioInterop owns the event sink; this module exposes the one operation the
 * bridge ability needs without letting it reach into channel internals. Keeping
 * the lookup in one place also means a future second bridge entry point cannot
 * invent its own allowlist.
 */
import { common } from '@kit.AbilityKit';
import { FlutterEngine } from '@ohos/flutter_ohos';
import {
  acceptBridgeEvent,
  isAllowedReceiver,
  hostEngine,
} from './StudioInterop';

/** Copies the untrusted Want parameter record into a Map. */
function toMap(source: Record<string, Object>): Map<string, Object> {
  const out = new Map<string, Object>();
  for (const key of Object.keys(source)) {
    out.set(key, source[key]);
  }
  return out;
}

/**
 * Forwards one event if the caller bundle and session are both allowed.
 *
 * [engine] and [context] are unused on purpose: the sink lives in
 * StudioInterop, which the host ability configured. Passing them keeps the call
 * site honest about what it has, and gives a future refactor a local place to
 * require an engine without introducing a second allowlist.
 */
export function forwardBridgeEvent(
  callerBundle: string,
  parameters: Record<string, Object>,
  engine: FlutterEngine | null,
  context: Object,
): boolean {
  void engine;
  void context;
  if (!isAllowedReceiver(callerBundle)) {
    return false;
  }
  return acceptBridgeEvent(callerBundle, toMap(parameters));
}

/** The engine the host ability created, or null before Dart is running. */
export function bridgeHostEngine(ability: Object): FlutterEngine | null {
  return hostEngine(ability as common.Context);
}
