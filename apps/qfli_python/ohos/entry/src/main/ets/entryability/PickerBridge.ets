import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { MethodCall, MethodResult } from '@ohos/flutter_ohos';

interface PickerDocument { uri: string; name: string; }

export function isPickerMethod(method: string): boolean { return method === 'pickDocument' || method === 'saveDocument' || method === 'pickPhotos' || method === 'readUri' || method === 'writeUri'; }
export function handlePickerCall(context: common.UIAbilityContext, call: MethodCall, result: MethodResult): void { runPickerCall(context, call, result); }
async function runPickerCall(context: common.UIAbilityContext, call: MethodCall, result: MethodResult): Promise<void> {
  try {
    switch (call.method) {
      case 'pickDocument': result.success(await pickDocument(context, call)); return;
      case 'saveDocument': result.success(await saveDocument(context, call)); return;
      case 'pickPhotos': result.success(await pickPhotos()); return;
      case 'readUri': result.success(await readUri(call.argument('uri') as string)); return;
      case 'writeUri': await writeUri(call.argument('uri') as string, call.argument('bytes') as Uint8Array); result.success(null); return;
      default: result.notImplemented();
    }
  } catch (error) { result.error('PICKER_ERROR', error instanceof Error ? error.message : String(error), null); }
}
async function pickDocument(context: common.UIAbilityContext, call: MethodCall): Promise<PickerDocument | null> {
  const options = new picker.DocumentSelectOptions();
  options.selectMode = call.argument('folder') as boolean ? picker.DocumentSelectMode.FOLDER : picker.DocumentSelectMode.FILE;
  const extensions = call.argument('extensions') as Array<string>;
  if (extensions != null && extensions.length > 0) options.fileSuffixFilters = extensions.map((extension: string) => `QFLI files|${extension.startsWith('.') ? extension : `.${extension}`}`);
  const uris = await new picker.DocumentViewPicker(context).select(options);
  return uris.length === 0 ? null : { uri: uris[0], name: uriName(uris[0]) };
}
async function saveDocument(context: common.UIAbilityContext, call: MethodCall): Promise<PickerDocument | null> {
  const name = String(call.argument('suggestedName') ?? 'qfli-project.json');
  const dot = name.lastIndexOf('.');
  const options = new picker.DocumentSaveOptions();
  options.newFileNames = [name];
  options.fileSuffixChoices = [`JSON|${dot > 0 ? name.substring(dot) : '.json'}`];
  const uris = await new picker.DocumentViewPicker(context).save(options);
  return uris.length === 0 ? null : { uri: uris[0], name: uriName(uris[0]) };
}
async function pickPhotos(): Promise<Array<PickerDocument>> {
  const options = new photoAccessHelper.PhotoSelectOptions();
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  options.maxSelectNumber = 20;
  const selection = await new photoAccessHelper.PhotoViewPicker().select(options);
  const documents: Array<PickerDocument> = [];
  for (const uri of selection.photoUris) documents.push({ uri: uri, name: uriName(uri) });
  return documents;
}
async function readUri(uri: string): Promise<Uint8Array> {
  const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
  try { const stat = await fs.stat(file.fd); const buffer = new ArrayBuffer(Number(stat.size)); const bytesRead = await fs.read(file.fd, buffer, { length: buffer.byteLength }); return new Uint8Array(buffer, 0, bytesRead); }
  finally { await fs.close(file.fd); }
}
async function writeUri(uri: string, bytes: Uint8Array): Promise<void> {
  const file = await fs.open(uri, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
  try { await fs.write(file.fd, bytes.buffer, { length: bytes.byteLength }); } finally { await fs.close(file.fd); }
}
function uriName(uri: string): string { const slash = uri.lastIndexOf('/'); return slash >= 0 ? decodeURIComponent(uri.substring(slash + 1)) : uri; }
