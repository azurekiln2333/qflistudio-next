/*
 * 接收别的应用分享的文件（鸿蒙）。
 *
 * `sendData` 一次可带多个文件，`viewData` 只带一个。两者都用
 * `ohos.want.action` 进到 EntryAbility，这里把文件复制进
 * `filesDir/shared_inbox/<批次>/`，再把批次交给 Dart。
 *
 * 复制用 `fileIo.copyFile`：由系统搬运，不把文件读进内存。
 */
import { fileIo } from '@kit.CoreFileKit';
import { common, Want } from '@kit.AbilityKit';
import { FlutterEngine, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';

export const SHARE_INBOX_CHANNEL = 'qflistudio/share_inbox';
const INBOX_DIR = 'shared_inbox';
const MAX_FILES = 16;
const MAX_FILE_BYTES = 2 * 1024 * 1024 * 1024;
const MAX_BATCH_BYTES = 512 * 1024 * 1024;

interface SharedFile {
  path: string;
  name: string;
  bytes: number;
  mimeType: string | null;
}

let channel: MethodChannel | null = null;
let pending: Map<string, Object> | null = null;
let dartListening = false;
let abilityContext: common.UIAbilityContext | null = null;

/** 由 EntryAbility 在引擎初始化后调用。 */
export function configureShareInbox(
  engine: FlutterEngine,
  context: common.UIAbilityContext,
): void {
  abilityContext = context;
  if (channel !== null) {
    return;
  }
  const inboxChannel = new MethodChannel(
    engine.dartExecutor.getBinaryMessenger(),
    SHARE_INBOX_CHANNEL,
  );
  inboxChannel.setMethodCallHandler({
    onMethodCall: (call: MethodCall, result: MethodResult): void => {
      if (call.method === 'takePending') {
        dartListening = true;
        const batch = pending;
        pending = null;
        result.success(batch);
      } else if (call.method === 'discard') {
        const id = call.argument('id') as string;
        if (!validBatchId(id)) {
          result.error('INVALID_ARGUMENT', '批次 id 无效', null);
          return;
        }
        const directory = `${inboxRoot()}/${id}`;
        try {
          fileIo.rmdirSync(directory);
        } catch (error) {
          // 目录已不在：删除是幂等的。
        }
        result.success(null);
      } else {
        result.notImplemented();
      }
    },
  });
  channel = inboxChannel;
}

/** 处理一个 want。没有文件时直接返回。 */
export function offerShareWant(want: Want, context: common.UIAbilityContext): void {
  abilityContext = context;
  const uris = shareUris(want);
  if (uris.length === 0) {
    return;
  }
  const source = want.action === 'ohos.want.action.viewData' ? 'viewData' : 'sendData';
  const batchId = makeBatchId();
  const files: SharedFile[] = [];
  let total = 0;
  let index = 0;
  for (const uri of uris) {
    if (files.length >= MAX_FILES || total >= MAX_BATCH_BYTES) {
      break;
    }
    const sourcePath = toPath(uri);
    if (sourcePath.length === 0) {
      continue;
    }
    const name = baseName(sourcePath);
    const target = `${inboxRoot()}/${batchId}/${pad(index + 1)}-${safeName(name)}`;
    try {
      ensureDirectory(`${inboxRoot()}/${batchId}`);
      fileIo.copyFileSync(sourcePath, target);
      const size = fileIo.statSync(target).size;
      if (size <= 0 || size > MAX_FILE_BYTES) {
        fileIo.unlinkSync(target);
        continue;
      }
      total += size;
      files.push({ path: target, name: name, bytes: size, mimeType: null });
      index++;
    } catch (error) {
      // 单个文件失败不影响整批。
      continue;
    }
  }
  if (files.length === 0) {
    try {
      fileIo.rmdirSync(`${inboxRoot()}/${batchId}`);
    } catch (error) {
      // 没建出来就不用删。
    }
    return;
  }
  const batch: Map<string, Object> = new Map<string, Object>();
  batch.set('id', batchId);
  batch.set('coldStart', !dartListening);
  batch.set('source', source);
  batch.set('files', files);
  if (dartListening && channel !== null) {
    channel.invokeMethod('incoming', batch);
  } else {
    // 只保留最后一批：更早的批次由 Dart 侧的 sweep 清理。
    pending = batch;
  }
}

function shareUris(want: Want): string[] {
  if (want.action !== 'ohos.want.action.sendData' && want.action !== 'ohos.want.action.viewData') {
    return [];
  }
  const collected: string[] = [];
  const stream = want.parameters?.['ability.params.stream'];
  if (Array.isArray(stream)) {
    for (const item of stream) {
      if (typeof item === 'string' && item.length > 0) {
        collected.push(item);
      }
    }
  } else if (typeof stream === 'string' && stream.length > 0) {
    collected.push(stream);
  }
  if (want.uri !== undefined && want.uri.length > 0) {
    collected.push(want.uri);
  }
  return collected;
}

function toPath(uri: string): string {
  if (uri.startsWith('file://')) {
    return uri.substring('file://'.length);
  }
  return uri.startsWith('/') ? uri : '';
}

function inboxRoot(): string {
  const context = abilityContext;
  if (context === null) {
    return `${INBOX_DIR}`;
  }
  return `${context.filesDir}/${INBOX_DIR}`;
}

function ensureDirectory(path: string): void {
  if (!fileIo.accessSync(path)) {
    fileIo.mkdirSync(path, true);
  }
}

function baseName(path: string): string {
  const parts = path.split('/');
  const name = parts.length === 0 ? '' : parts[parts.length - 1];
  return name.length === 0 ? 'shared-file' : name;
}

function safeName(name: string): string {
  return name.replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').substring(0, 120);
}

function pad(value: number): string {
  const text = value.toString();
  return text.length >= 4 ? text : '0'.repeat(4 - text.length) + text;
}

function makeBatchId(): string {
  const suffix = Math.random().toString(36).substring(2, 6);
  return `${Date.now()}-${suffix}`;
}

function validBatchId(id: string): boolean {
  return typeof id === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(id);
}
