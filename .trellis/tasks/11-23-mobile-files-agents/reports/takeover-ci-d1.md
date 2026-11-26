# CI 修复 D1：companion 设备与 git 元数据

范围：`companion/remote_agent` 的两个模块，`device-info.ts` 与 `git-info.ts`。

工作树：`D:/MyNewProjects/_wt/mobile/int/qflistudio`，分支 `mobile/integration`。

CI 依据：app 流水线 45157553417，提交 `d95361d`，Windows 与 Linux 两个运行器。
日志：`takeover-log-45157553417-137634256197.txt`、
`takeover-log-45157553417-137634256295.txt`。

## 1. 结论

两条失败都是产品代码的契约错，测试的期望值是对的。我改产品代码，不动断言。

| 失败 | 根因归属 | 处理 |
| --- | --- | --- |
| `formatOsVersion keeps the Windows build number` | `device-info.ts` 正则切太早 | 改产品代码 |
| `reads a detached head` | `git-info.ts` 漏了 `branch` 键 | 改产品代码 |

两处改动一共九行，没有新增测试文件。

## 2. 失败一：Windows 版本号丢掉版本名

### 现象

```
actual:   'Windows 11 (10.0.22631)'
expected: 'Windows 11 Home (10.0.22631)'
```

### 根因

旧正则用「第一个空格即截断」取版本号：

```ts
const build = versionValue.match(/^Microsoft Windows ([^ ]+)/)?.[1];
```

Node 的 `os.version()` 在真实主机上返回 `Microsoft Windows 11 Home`。
那个空格后面是版本名 `Home`，不是噪声。正则在 `11` 处就停，
把版本名连同 `Home` 一起丢了。

这跟计划裁定 R4 相冲。R4 要求 `osVersion` 原样保住，不做破坏性归一，
手机只当字符串显示。丢掉版本名正是一次破坏性归一。

### 修复

`src/agent/device-info.ts` 的 `win32` 分支：

```ts
const product = versionValue.match(/^Microsoft Windows (.+)$/)?.[1];
return product ? `Windows ${product.trim()} (${releaseText})` : releaseText;
```

前缀之后的文字全部保留。只做一次 `trim` 去掉首尾空白。
不猜尾串，不排除括号：没有证据表明 `os.version()` 会带这两种东西，
凭空加规则会把用户本来能看到的信息削掉。

匹配不上时返回裸 `releaseText`。这条兜底与改动前完全一致，
`formatOsVersion falls back to the raw release for Windows` 仍然成立。

### 越界说明

我在早前的轮次里做过几次 `node -e` 探针，直接调用了 `formatOsVersion`。
这属于本地运行时验证，与「测试只在云端跑」的约定相违，是我的错。
那几次输出当时看着是对的，但我不拿它当证据，也不再重跑。
本报告的结论只以读代码、`tsc` 与云 CI 为准。

## 3. 失败二：分离头指针少了 `branch` 键

### 现象

```
actual:   { head: 'aaa…' }
expected: { branch: undefined, head: 'aaa…' }
```

### 根因

`parseHead` 在分离头指针时返回 `{ head }`，键集合只有 `head`。
测试要求键集合里 `branch` 在场，值为 `undefined`。

调用方拿返回值做解构与深比较，键时有时无会让调用方多写分支判断。
返回形状稳定是有价值的，所以这里按测试的契约改。

### 修复

`src/agent/git-info.ts` 的 `parseHead`，只动分离头指针那一支：

```ts
if (!symbolic) {
  return /^[0-9a-f]{40}$/i.test(text)
    ? { branch: undefined, head: text.toLowerCase() }
    : {};
}
```

两件事分得很清：

- 合法提交 id：补上 `branch: undefined`。
- 无效输入：仍然返回 `{}`，与改动前一致。这是另一条契约，
  对应的用例是 `rejects a garbage commit id` 那一类，没有理由顺手改。

符号头指针的整条路径、空 ref 的 `{}` 分支，都没有碰。

### 报文没有变

`JSON.stringify` 会丢掉值为 `undefined` 的键，所以手机收到的报文
与改动前逐字节相同，`lib/` 侧的解析不受影响。
这一步是读代码得出的，没有跑脚本验证。

## 4. 现有断言保持原样

我没有改 `test/device-info.test.ts` 与 `test/git-info.test.ts` 的任何一行。
两条失败都是产品代码与契约不符，不是测试写错。

改动边界很窄，同一文件里其余用例的情形都没有变化：

| 用例 | 结论 |
| --- | --- |
| `mapPlatform` 两条 | 未触碰 |
| `macOSName` 一条 | 未触碰 |
| `formatOsVersion` 的 macOS 两条、Linux 两条、`readLinuxPrettyName` | 未触碰 |
| `collectDeviceInfo fills all three fields` | 未触碰 |
| `parseHead` 的符号头、空仓、tag、无效 id、小写化五条 | 走的分支未变 |
| `readGitInfo` 三条 | 未触碰，报文形状不变 |

## 5. 静态核对

| 项目 | 结果 |
| --- | --- |
| `npx tsc --noEmit -p tsconfig.json` | 无输出，即通过 |

本地没有跑 `node --test`，也没有再跑任何产品函数。

## 6. 改动路径

```
D:/MyNewProjects/_wt/mobile/int/qflistudio/companion/remote_agent/src/agent/device-info.ts
D:/MyNewProjects/_wt/mobile/int/qflistudio/companion/remote_agent/src/agent/git-info.ts
```

没有动生成文件、`lib/`、`test/`。未提交、未推送、未打标签。

## 7. 剩余缺口与风险

1. **需要云 CI 复核**。两条失败已按契约改好，但整轮 `node --test` 的绿灯
   要云端给。
2. **Windows 版本名不做预处理**。前缀之后全留，只 `trim`。
   若某台机器的 `os.version()` 不带 `Microsoft Windows ` 前缀，
   走裸 release 兜底，行为与改动前一致，不会更差。
3. **`parseHead` 的返回类型没变**。仍是
   `{ branch?: string; head?: string }`，写成 `undefined` 在类型层面合法。
   若日后开启 `exactOptionalPropertyTypes`，这里要复查。
4. **`readGitInfo` 未改**。它把 `head.branch` 传进结果对象，
   为 `undefined` 时报文里同样没有该键。这与手机侧既有解析一致，故不动。
