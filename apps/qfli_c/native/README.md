# 原生执行后端（picoc）

这是 C 版 App 的**可选**执行后端。默认不启用——App 实际交付的是纯 Dart 解释器
（`packages/qfli_c_runtime`），它不需要 NDK、不需要按 ABI 出多个 `.so`，在所有平台上
都能跑，覆盖面也够教学用。

只有当你想换性能更好的 picoc、或者需要 picoc 的某些语义时，才按本文打开这条路径。

```
Dart → MethodChannel('qfli_c/native') → ArkTS → libqfli_c.so → picoc
```

## 为什么需要 ArkTS 那一层

Flutter 的 Dart 代码不能直接调 NAPI。链路上必须有一个 ArkTS 环节，而 ArkTS 的
`import 'libqfli_c.so'` 是**构建期解析**的——`.so` 不存在，整个 App 直接编不过。
所以本目录的文件刻意放在 `native/` 下而不是 `ohos/` 里：默认构建不会碰到它们。

## 目录

| 路径 | 作用 |
| --- | --- |
| `CMakeLists.txt` | 构建 `libqfli_c.so` |
| `src/qfli_c_bridge.h` / `.c` | 驱动 picoc 跑一次，拿回输出与退出码（纯 C，无平台依赖） |
| `src/platform_ohos.c` | picoc 的 HarmonyOS 平台层（标准输入/输出、文件读取、退出跳转） |
| `src/qfli_c_napi.cpp` | NAPI 外壳，把 `qfli_c_run()` 暴露给 ArkTS |
| `ohos/QfliCNative.ets` | ArkTS 接线：把 `.so` 挂到 MethodChannel 上 |

## 步骤

### 1. 取 picoc 源码

picoc 的 GitHub 仓库已经废弃，实际代码在 GitLab：

```bash
cd apps/qfli_c/native
git clone --depth 1 https://gitlab.com/zsaleeba/picoc.git third_party/picoc
rm -rf third_party/picoc/.git
```

> 不要用 `github.com/zsaleeba/picoc`——那个仓库只剩一个指向 GitLab 的 README。

### 2. 让 hvigor 构建这个 .so

在 `ohos/entry/build-profile.json5` 里加 `externalNativeOptions`（路径相对于
`ohos/entry/`，所以要往上走两级到 App 根目录）：

```json5
{
  "apiType": "stageMode",
  "buildOption": {
    "externalNativeOptions": {
      "path": "../../native/CMakeLists.txt",
      "arguments": "",
      "cppFlags": "",
      "abiFilters": ["arm64-v8a"]
    }
  },
  "targets": [
    { "name": "default", "runtimeOS": "HarmonyOS" },
    { "name": "ohosTest" }
  ]
}
```

`abiFilters` 先只出 `arm64-v8a`。要覆盖 32 位设备再加 `armeabi-v7a`——注意那会让
安装包里的原生库体积翻倍。

### 3. 把 .so 放到模块的 native 库目录

```bash
mkdir -p ohos/entry/libs/arm64-v8a
cp <构建产物>/libqfli_c.so ohos/entry/libs/arm64-v8a/
```

> **不需要**改 `oh-package.json5`。`ohos/entry/libs/<abi>/` 就是模块的 native 库目录，
> hvigor 会自动把它打包进 HAP——Flutter 插件拷 `libapp.so` 用的也是这个目录。
> （本节早先写的 `"libqfli_c.so": "file:./libs"` 依赖是错的，实测不需要，
> 而且那个路径 `ohos/libs/` 并不存在。已在 Python 版上实测确认：
> `libs/arm64-v8a/libqfli_py.so` 直接出现在 HAP 里。）

> ⚠️ **同一个坑先在这里提醒**：`src/qfli_c_napi.cpp` 是 C++，所以这个 `.so` 会
> 依赖 `libc++_shared.so`。**编译期完全正常，只有真机才炸**——dlopen 失败，
> ArkTS 的 `import` 拿到 `undefined`，报出来是
> `Cannot read property run of undefined`。设备上 `/system/lib64/libc++_shared.so`
> 是存在的，但不在应用的 linker namespace 里，照样 `errno=2`。
>
> 两道防线（Python 版已经踩过并修好，细节见 `apps/qfli_python/native/README.md`）：
> 1. CMake 里加 `target_link_libraries(qfli_c PUBLIC -static-libstdc++)`，
>    把 C++ 标准库静态链进来；
> 2. 链接后用 `apps/qfli_python/native/tools/check_so_deps.py` 校验一遍
>    `DT_NEEDED`（纯 Python 解析 ELF，直接传 `.so` 路径即可），
>    出现 HAP 里不会带的库就让构建失败。

### 4. 接上 ArkTS

把 `native/ohos/QfliCNative.ets` 复制到
`ohos/entry/src/main/ets/plugins/QfliCNative.ets`，然后在
`ohos/entry/src/main/ets/entryability/EntryAbility.ets` 的
`configureFlutterEngine` 里加两行：

```ts
import { registerQfliCNativeChannel } from '../plugins/QfliCNative';

// ...在 configureFlutterEngine 内部，super.configureFlutterEngine(...) 之后：
registerQfliCNativeChannel(flutterEngine);
```

### 5. 构建

```bash
cd ohos
hvigorw assembleHap --mode module -p product=default
```

## Dart 侧不用改

`CProgramRunner`（`lib/c_runner.dart`）本来就是「先探测原生后端，不可用就退回 Dart
解释器」的结构：

- 通道不存在（没打进 `.so`）→ 探测返回 false → 走 Dart 解释器
- 原生后端可用 → 走 picoc
- 原生后端**存在但执行失败** → 把错误显示出来，**不**静默换后端

最后一条是有意的：悄悄退回解释器会让用户看到的运行结果和设备的真实行为对不上，
排查问题时会被误导。

## 与 Dart 解释器的取舍

| | Dart 解释器（默认） | picoc（本目录） |
| --- | --- | --- |
| 需要 NDK | 否 | 是 |
| 每 ABI 一份 `.so` | 否 | 是 |
| 可测性 | 63 个用例覆盖，`flutter test` 就能跑 | 只能上真机验 |
| 执行速度 | 慢（Dart 里逐条解释） | 快 |
| 教学覆盖面 | 预处理、结构体、联合、typedef、函数指针、多文件 | 大致相当，个别 C99 细节更全 |

教学规模的程序（几十到几千行、无 IO 密集）用 Dart 解释器完全够；picoc 的价值主要在
「跑得久一点的计算题」上。

## 已知限制

- **交互式 stdin 不支持**。两个后端都是「先跑完再输出」的模型，所以 `scanf`/`getchar`
  拿到的是一次性喂进去的输入。App 侧的约定是：项目根目录放 `input.txt`，内容即为
  标准输入。要真正的交互式 stdin，得把解释器改成可挂起/可恢复的结构，那是另一个
  量级的改造。
- **`fscanf` 只认 stdin**。`fopen` 返回的 `FILE*` 没有真正的文件语义，传非 stdin 的
  流会返回 `-1`。
- **本目录的 C 代码尚未在真机编译验证过**。picoc 的 API 用法是对着它自己的
  `picoc.c` / `platform/platform_unix.c` 写的，但 HarmonyOS NDK 不在当前开发环境里，
  所以没有跑过 `hvigorw`。第一次构建时如果报错，优先看 CMake 里的 `UNIX_HOST`
  分支和 `libace_napi.z.so` 的链接。
