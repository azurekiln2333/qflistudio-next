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
  const inboxChannel = new MethodChannel(
    engine.dartExecutor.getBinaryMessenger(),
    SHARE_INBOX_CHANNEL,
  );
  const previous = channel;
  if (previous !== null) {
    // 旧引擎已经拆掉：先拆掉它的处理器，再重置监听标记。
    // 否则新引擎的 Dart 还没调 takePending，批次就会推给一个没人接的通道。
    try {
      previous.setMethodCallHandler(null);
    } catch (error) {
      // 旧引擎已销毁时拆处理器会抛，忽略。
    }
    dartListening = false;
  }
  inboxChannel.setMethodCallHandler({
    onMethodCall: (call: MethodCall, result: MethodResult): void => {
      if (call.method === 'takePending') {
        dartListening = true;
        const batch = pending;
        pending = null;
        if (batch === null) {
          result.success(null);
        } else {
          result.success(batch);
        }
      } else if (call.method === 'discard') {
        const id = call.argument('id') as string;
        if (!validBatchId(id)) {
          result.error('INVALID_ARGUMENT', '批次 id 无效', null);
          return;
        }
        // 目录已不在时这里抛，捕获即幂等。
        try {
          fileIo.rmdirSync(`${inboxRoot()}/${id}`);
        } catch (error) {
          // 已经删掉了。
        }
        result.success(null);
      } else {
        result.notImplemented();
      }
    },
  });
  channel = inboxChannel;
}

/**
 * 处理一个 want。没有文件时直接返回。
 *
 * 冷启动时 `onCreate` 就调到这里：复制走 async，不阻塞 Ability 启动。
 * 引擎未就绪时批次先进 `pending`，由 Dart 的 `takePending` 取走。
 */
export function offerShareWant(want: Want, context: common.UIAbilityContext): void {
  abilityContext = context;
  const uris = shareUris(want);
  if (uris.length === 0) {
    return;
  }
  const source = want.action === 'ohos.want.action.viewData' ? 'viewData' : 'sendData';
  // 复制可能搬几百 MB：不能占着 UI 线程，否则 onCreate 会卡成 ANR。
  copyBatch(uris, source).catch((error: Error) => {
    console.error(`share inbox: ${error.message}`);
  });
}

async function copyBatch(uris: string[], source: string): Promise<void> {
  const batchId = makeBatchId();
  const batchDir = `${inboxRoot()}/${batchId}`;
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
    const target = `${batchDir}/${pad(index + 1)}-${safeName(name)}`;
    try {
      ensureDirectory(batchDir);
      const declared = declaredSize(sourcePath);
      if (declared !== null) {
        if (declared > MAX_FILE_BYTES || total + declared > MAX_BATCH_BYTES) {
          continue;
        }
      }
      await fileIo.copyFile(sourcePath, target);
      const size = fileIo.statSync(target).size;
      if (size > MAX_FILE_BYTES || total + size > MAX_BATCH_BYTES) {
        fileIo.unlinkSync(target);
        continue;
      }
      total += size;
      const file: SharedFile = {
        path: target,
        name: name,
        bytes: size,
        mimeType: null,
      };
      files.push(file);
      index++;
    } catch (error) {
      // 单个文件失败不影响整批；半截文件不能计入批次。
      try {
        fileIo.unlinkSync(target);
      } catch (cleanupError) {
        // 没拷出来就没有半成品。
      }
      continue;
    }
  }
  if (files.length === 0) {
    try {
      fileIo.rmdirSync(batchDir);
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

/** 文件大小；拿不到时返回 null，交给复制后的实际大小判断。 */
function declaredSize(path: string): number | null {
  try {
    const stat = fileIo.statSync(path);
    return stat.size;
  } catch (error) {
    return null;
  }
}

function shareUris(want: Want): string[] {
  const action = want.action;
  if (action !== 'ohos.want.action.sendData' && action !== 'ohos.want.action.viewData') {
    return [];
  }
  const collected: string[] = [];
  // 同一批里同一个 uri 只收一次：流和 want.uri 可能指向同一个文件。
  const seen: Set<string> = new Set<string>();
  const push = (value: string): void => {
    if (value.length === 0 || seen.has(value)) {
      return;
    }
    seen.add(value);
    collected.push(value);
  };
  const parameters = want.parameters;
  if (parameters !== undefined) {
    const stream: Object | undefined = parameters['ability.params.stream'];
    // ArkTS 不收 `any`：先按数组取，再逐项确认是字符串。
    if (Array.isArray(stream)) {
      const list = stream as Object[];
      for (const item of list) {
        if (typeof item === 'string') {
          push(item);
        }
      }
    } else if (typeof stream === 'string') {
      push(stream);
    }
  }
  const uri = want.uri;
  if (uri !== undefined) {
    push(uri);
  }
  // viewData 只带一个文件；sendData 一次最多 16 个。
  const limit = action === 'ohos.want.action.viewData' ? 1 : MAX_FILES;
  return collected.slice(0, limit);
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
