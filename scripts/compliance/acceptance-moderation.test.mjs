// 验收脚本入口自检：只验证模块可加载与导出形状，不启动真实服务。
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const script = join(here, 'acceptance-moderation.mjs');

test('导出 runAcceptance 与 main，供手动复跑', async () => {
  const mod = await import(pathToFileURL(script).href);
  assert.equal(typeof mod.runAcceptance, 'function');
  assert.equal(typeof mod.main, 'function');
  assert.equal(mod.main.length, 0);
});
