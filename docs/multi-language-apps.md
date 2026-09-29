# 多语言 App：各语言在鸿蒙上的可行性与现状

> 本文保留 2026-09-21 的技术研究记录，其中的 `apps/`、`packages/` 和 pub workspace 路径是拆分前布局。当前 13 个并列 Git 仓库的检出与构建命令见 [README](../README.md#仓库结构)。

回答一个问题：**C / C++ / Python / Java / Lua / Web / Dart 这七个语言，各自能不能在鸿蒙上先做起来、
做到哪一步、还差什么。**

本文只讲「多语言这一层」；鸿蒙为什么不能跑编译器、C 版怎么落地、DevEco 怎么构建，
都在 [`c-app-and-harmonyos.md`](./c-app-and-harmonyos.md) 里，本文不重复。

整理日期：2026-09-21

---

## 一、结论速览

| 语言 | 现在能不能跑 | 靠什么跑 | 本版状态 |
| --- | --- | --- | --- |
| **C** | ✅ 能 | 应用内 C 解释器（纯 Dart，`qfli_c_runtime`，约 7000 行） | 已交付，73 个运行时用例 |
| **C++** | ⏳ 还不能 | C++ 本地运行时接入点 | App、模板和本地内容已就位，运行时开发中 |
| **Web** | ✅ 能 | 本地静态服务器 + 调试桥（内核自带，无需解释器） | 已交付，11 个接线用例 |
| **Python** | ⏳ 还不能 | 待写：应用内 Python 子集解释器（纯 Dart） | App 与接缝已就位，解释器未写 |
| **Java** | ⏳ 还不能 | 待写：应用内 Java 子集解释器（纯 Dart） | App 与接缝已就位，解释器未写 |
| **Lua** | ⏳ 还不能 | 待写：应用内 Lua 子集解释器（纯 Dart） | App、模板和本地内容已就位，解释器未写 |
| **Dart** | ⏳ 还不能 | 待写：应用内 Dart 子集解释器（纯 Dart） | App 与接缝已就位，解释器未写 |

「还不能」的语言不是卡在工程接线上——**App、档位、入口识别、退出码、本地教程和示例代码
页面已经通了**，卡的是解释器本身。C 版是这条路的参考实现，其余语言沿用同一套模式。

---

## 二、那条定死的硬约束

鸿蒙的普通应用被 SELinux 挡在 `exec` 之外：既调不动设备上的编译器，也拉不起打包在
HAP 里的可执行文件。官方给的 HNP（OpenHarmony Native Package）面向「生产力应用」，
普通应用拿不到资格。

**但沙箱限制的是「执行别的程序」，从来不限制「应用解释自己的数据」。**
所以对普通应用来说，唯一走得通的路是：**自带解释器，在当前进程里跑用户写的源码。**

这条约束对所有语言一视同仁，也是下面所有设计的出发点。

> 详细论证、C 版实测结论、HNP 的申请门槛见 [`c-app-and-harmonyos.md`](./c-app-and-harmonyos.md)。

---

## 三、各语言分别怎么落地

### C —— 已交付

`packages/qfli_c_runtime`，纯 Dart，词法 → 预处理 → 语法 → 解释四层。
两个后端，按顺序尝试：

1. **原生后端**（可选）：`libqfli_c.so` + picoc，走 ArkTS/NAPI 通道。没打进 `.so` 时
   直接跳过，不影响功能。
2. **Dart 解释器**（默认）：所有平台都能跑，这是实际交付的路径。

多文件工程按「没有链接器的链接」处理：项目内所有 `.c` 各自当独立翻译单元编译，
共享函数表，`#include "utils.h"` 靠 files 表解析。

### Web —— 已交付，而且不需要解释器

这是当前语言 App 里唯一「内核已经具备完整能力」的：内核的 `LocalWebServer` 会

- 绑 `127.0.0.1` 随机端口，把项目目录当网站 serve 出去（带目录穿越防护）；
- 往 HTML 的 `</head>` 前注入一段调试桥，劫持 `console.log/info/warn/error` 和
  `window.onerror`，POST 到 `/__debug`；
- 编辑器的终端面板订阅 `debugStream`，把页面日志实时显示出来（`editor_page.dart`）。

所以 Web 版 App **不注入任何运行后端**——`runner` 留空反而是完整的。
点运行会起服务器、把预览地址用 SnackBar 显示出来（带「复制地址」），
页面里的 `console.log` 直接出现在终端面板。

**鸿蒙上唯一的缺口**：拉起系统浏览器要原生通道（`UrlOpener` 的 ohos 分支是空的）。
所以真机上现在的用法是「复制地址」，或者后续做一个应用内 WebView。

### Python / Java / Dart —— 同一个模式，解释器待写

Python、Java、Dart、C++、Lua 五个 App 已经建好，档位、模板、入口、本地内容页面全部通了，
运行后端是一个明确标注「开发中」的占位实现。**接入方式是在 `lib/<id>_runner.dart` 里把占位返回换成真实
解释器的调用**，其余接线一行都不用改。

为什么这三个要自己写解释器、而不能像桌面端那样调 `python` / `javac` / `dart`：
回到第二节那条硬约束——设备上没有这些东西，有也 exec 不了。

---

## 四、架构：一个内核 + N 个语言 App

### 为什么一个语言一个 App

集成在同一个应用里，多个解释器（再加未来十几个语言）会让体积膨胀到不可接受。
每个语言一个 App，共享同一套 IDE 内核，各自只带自己需要的运行时。

### 目录

```
packages/qfli_studio_core     IDE 内核：编辑器、文件树、高亮、主题、项目管理、教程加载
packages/qfli_c_runtime       C 运行时（纯 Dart 解释器 + 可选原生后端）
apps/qfli_c                   C 版
apps/qfli_cpp                 C++ 版
apps/qfli_web                 Web 版
apps/qfli_python              Python 版
apps/qfli_java                Java 版
apps/qfli_lua                 Lua 版
apps/qfli_dart                Dart 版
tool/new_language_app.dart    App 生成器
```

这些包在一个 Dart pub workspace 里，一次 `flutter pub get` 全部解析，共用一份
`pubspec.lock`；只有根 pubspec 的 `dependency_overrides` 生效。

### 每个 App 只有三个文件不同

复制一整套平台工程（android / ios / macos / linux / windows / web / ohos）之后，
真正与语言相关的只有：

| 文件 | 作用 |
| --- | --- |
| `lib/main.dart` | 档位：收窄模板、指定入口文件、挂上运行后端 |
| `lib/<id>_runner.dart` | 运行后端（解释器接入点） |
| `test/<id>_app_test.dart` | 接线测试 |

其余都是内核提供的同一套 UI。

### 两个接缝

**`StudioProfile`**（`services/studio_profile.dart`）——在 `runApp` 之前定档的常量：

```dart
const StudioProfile pythonProfile = StudioProfile(
  id: 'python',
  appTitle: 'QFLIStudio+ Python 版',
  templates: [ProjectTemplate.empty, ProjectTemplate.python],
  runner: PythonProgramRunner(),
  entryFileNames: ['main.py', 'src/main.py'],
);
```

用可变静态（`StudioProfile.current`）而不是 `InheritedWidget`，是因为 `ProjectStore`、
`RunnerService` 这些非 Widget 代码也要读它。

**`ProgramRunner`**——运行按钮的注入点：

```dart
Future<ProgramRunResult?> run({required String projectPath, required String entryFile});
```

**返回 `null` 表示「这个后端不处理这种文件，交回内核」**，这是整个设计的关节：
语言 App 只接管自己的后缀，`.html`、`.c` 等交回内核的默认分流。

`ProgramRunResult` 的字段全是 `final`，所以后端要用 `StreamController` +
`scheduleMicrotask` 来推非挂起的输出。

**退出码的约定（所有语言 App 都要遵守）**：

| 情况 | `exitCode` | 终端上显示 |
| --- | --- | --- |
| 程序真的跑了 | 程序自己的退出码（`sys.exit(3)` → 3） | `（运行结束，退出码 3）` |
| **程序根本没跑起来** | `kProgramNotRunExitCode` = **127** | `（运行结束，退出码 127）` |

第二行必须是 127，**不能是 1 或 2**。终端面板（`lib/editor/terminal_pane.dart`）
把非 0 一律渲染成「（运行结束，退出码 N）」，于是任何小整数都会被读成
「程序自己跑完、报错退出」。真机上真实误导过一次：Python 版的后端 `.so`
没打进 HAP 时显示「运行结束，退出码 1」，看起来像程序报错，实际一行都没执行。

127 借的是 shell 的 `command not found` 约定——正常程序不会主动返回它，
所以终端上的两句话一眼就能分开。判定「是环境坏了还是代码错了」全靠这个。

「后端不可用」「源码读不出来」「原生调用抛异常」这类分支全部算第二行。

### 每个语言的双后端设计

沿用 C 版的形态，解释器类语言都可以有两条后端，藏在同一个 `ProgramRunner` 后面：

| 后端 | 形态 | 适用 |
| --- | --- | --- |
| A：应用内解释器 | 纯 Dart | **普通鸿蒙应用唯一能用的**，默认路径 |
| B：原生 | `.so` + NAPI（可选） | 有 NDK、愿意按 ABI 出包时提性能 |

命名约定（C 版已确立）：运行时包对外导出 `start<Lang>Source(...)` 返回一个 session
（带 `stdout` / `stderr` / `exitCode`），App 里的 `<Lang>ProgramRunner.run` 负责把它
适配成 `ProgramRunResult`。

---

## 五、已经交付的东西

### 1. 七个语言 App

用 `tool/new_language_app.dart` 从 `apps/qfli_c` 生成，平台品牌信息（applicationId、
bundleName、窗口标题、应用名、启动页标题）一次性铺到 android / ios / macos / linux /
windows / web / ohos 七个平台。

生成器是**合并**语义（覆盖同名文件、不删除已有文件），重复执行幂等。

### 2. 七份入门教程（JSON）

`packages/qfli_studio_core/assets/tutorials/` 下 `c / cpp / web / python / java / lua / dart`
七份，每课都有讲解、示例代码、预期输出和练习题。

### 3. 教程加载器

`models/tutorial.dart`（数据模型）+ `services/tutorial_service.dart`（加载与解析），
已在核心包 `pubspec.yaml` 声明 assets，11 个用例覆盖解析、资产加载、字段完整性、
id 唯一性、缓存命中。

### 4. 测试

| 包 | 用例数 |
| --- | --- |
| `qfli_studio_core` | 73 |
| `qfli_c_runtime` | 73 |
| `apps/qfli_c` | 25 |
| `apps/qfli_cpp` | 11 |
| `apps/qfli_web` | 11 |
| `apps/qfli_python` | 10 |
| `apps/qfli_java` | 10 |
| `apps/qfli_lua` | 11 |
| `apps/qfli_dart` | 10 |
| **合计** | **224** |

```bash
# 全量静态检查
flutter analyze

# 各包测试（apps/* 必须加 --no-pub：它们带 ohos/ 平台目录，
# 不加会先做全平台工具链校验，本机没有 HarmonyOS SDK 会报 No Hmos SDK found 并退出 1，
# 一个用例都不跑——看着像测试挂了，其实是环境检查没过）
flutter test --no-pub
```

---

## 六、教程 JSON 的格式

路径：`packages/qfli_studio_core/assets/tutorials/<language>.json`

```jsonc
{
  "language": "python",
  "displayName": "Python",
  "schemaVersion": 1,
  "updatedAt": "2026-09-19",
  "runtime": {
    "kind": "interpreter",        // interpreter | static-server
    "status": "planned",          // available | planned
    "engine": "应用内 Python 子集解释器（纯 Dart，开发中）",
    "stdin": "项目根目录放 input.txt，内容就是程序的标准输入",
    "limits": "单次运行有 10 秒墙钟上限和 2 亿步兜底上限"
  },
  "chapters": [
    {
      "id": "basics",
      "title": "基础",
      "lessons": [
        {
          "id": "hello",
          "title": "第一个程序",
          "summary": "一句话说明这一课解决什么问题",
          "concepts": ["print", "字符串"],
          "explain": "正文讲解",
          "code": "print(\"你好\")",   // 可直接运行
          "output": "你好",
          "tasks": [{ "prompt": "题目", "hint": "提示", "answer": "参考答案" }]
        }
      ]
    }
  ]
}
```

Web 的 `runtime.kind` 是 `static-server`，用 `stdout` 字段说明页面日志怎么回传，
而不是 `stdin`。

**为什么用 JSON 而不是写在 Dart 里**：教程是数据，不是代码。放在 JSON 里可以单独
校订、可以校验、将来可以按语言增量下载，不用为改一个错别字重新编译 App。

**页面**：离线语言 App 的第二页使用 `TutorialService` 展示本地 JSON 教程，第三页从同一份
类型化教程数据展示可复制示例代码。根工程仍使用联网社区的教程 / 讨论页面，不受离线档位影响。

> 别和底部导航的「教程」页搞混：那是**社区**里的教程帖（服务端内容，`post.type == 'tutorial'`），
> 和这里随包分发的本地入门教程是两回事。前者是别人写的帖子，后者是离线可用的语言教程。

---

## 七、路线图

按「先把能做的做起来」排序，每阶段都能独立交付、独立验证。

### 阶段 0：接线与数据 ✅ 已完成

七个 App、七份教程 JSON、教程加载器、离线教程与示例页面、生成器。**这一阶段不含任何新解释器**，
但把「一个语言一个 App」的全部接缝验证掉了。

### 阶段 1：Python 解释器（建议下一个做的）

Python 是除 C 之外最适合先做的语言之一：语法子集小（缩进块 + 表达式 + 内建函数），
初学者需求最大，而且**教程里的 12 课正好可以当验收用例**——教程写什么，
解释器就得能跑什么，两边天然对得上。

要写的东西：缩进感知的词法 → 语法 → 求值器 → 内建（`print` / `input` / `range` /
`len` / `sorted` / `sum` / `max` / `min` / 列表与字典方法）。参考 `qfli_c_runtime`
的分层，规模大致同量级。

标准输入沿用 C 版的约定（项目根目录 `input.txt`），这样两个 App 的行为一致。

### 阶段 2：Java 解释器

比 Python 重：要处理类外壳（`class Main` / `public static void main`）、静态方法、
基本类型与包装类型、`String` 不可变、`ArrayList` 与数组的区别。教程里的 10 课同样
可以当验收用例。

### 阶段 3：Dart 解释器

Dart 的语法面最宽（`final` / `const`、`$` 插值、命名参数、`=>`、`List` / `Map`、
`@override`），但教程只用到一个很窄的子集，可以按子集来做。

### 阶段 4：C++ / Lua 解释器

C++ 和 Lua 的 App 壳、模板、本地教程和示例代码已经存在。下一步分别实现运行时，
并保持 `kProgramNotRunExitCode` 的诚实失败语义。

### 阶段 5：鸿蒙真机验证

见第九节——签名和真机安装目前还没走完，这是唯一一处「代码好了但没在设备上验证过」的
环节，优先级取决于什么时候要发版。

---

## 八、加第 8 个语言要做什么

内核里已经有 16 个 `ProjectTemplate`（Java / Python / C / C++ / Web / Dart / Lua /
JavaScript / TypeScript / Kotlin / Go / Rust / C# / PHP / Ruby / 空项目），
所以加新语言主要是三件事：

1. **在 `tool/new_language_app.dart` 的 `_specs` 里加一条**：

   ```dart
   _Spec(
     id: 'go',
     displayName: 'Go',
     template: 'go',                                  // ProjectTemplate 的枚举成员名
     entryFileNames: ['main.go', 'src/main.go'],
     runnerClass: 'GoProgramRunner',
     sourceExtensions: ['.go'],
     description: 'QFLIStudio+ Go 版：手机上的 Go IDE，本地解释执行。',
     htmlDescription: '手机上的 Go IDE，本地解释执行。',
     pendingRunner: true,
   ),
   ```

2. **跑生成器**：

   ```bash
   dart run tool/new_language_app.dart go          # 生成 apps/qfli_go 并登记进 workspace
   dart run tool/new_language_app.dart --force go  # 已存在时覆盖（合并，不删除）
   flutter pub get
   ```

   生成器会顺手把 `apps/qfli_go/ohos` 的依赖装上（`npm install` + `ohpm install`），
   否则这个 App 在 DevEco 里连 Sync 都过不去——见下一节。

3. **写解释器**，然后改 `lib/go_runner.dart`。

> `template` 填的是**枚举成员名**，不是展示名：Web 的成员叫 `html`，展示名才是 `Web`。
> 模板统一把源码放在 `src/` 下，所以 `entryFileNames` 里要同时包含根目录和 `src/` 两种
> 形式——生成的测试里有一条专门断言这件事。

### 新 App 的 `ohos/` 必须先装依赖，否则 Sync 直接失败

新生成的 App 在 DevEco 里一 Sync 就报：

```
hvigor ERROR: Error Code: 00308018 Unknown Error
Error Cannot find module 'flutter-hvigor-plugin'
```

**这不是配置写错了，是 `ohos/` 下的依赖没装。** 本机上有两件事**都不会自动发生**：

| 步骤 | 装什么 | 谁不做 | 为什么 |
| --- | --- | --- | --- |
| `npm install` | `flutter-hvigor-plugin` | flutter 工具 | 正常由 `installHvigorPlugin` 负责，但它在 `ensureReadyForPlatformSpecificTooling` 里排在 `updateLocalProperties` **后面**；后者找不到 HarmonyOS SDK 就直接退出，永远轮不到它 |
| `ohpm install` | `@ohos/hypium` 等 | 需要手动触发 | DevEco 打开项目时会跑这一半 |

`hvigorconfig.ts` 在**配置阶段**就要加载 `flutter-hvigor-plugin`，所以缺了它连 Sync
的门都进不去。手工补：

```bash
cd apps/qfli_go/ohos
npm install --no-audit --no-fund
ohpm install          # DevEco 终端里；或见下面的命令行绕法
```

生成器现在会自动做这两步（见 `tool/new_language_app.dart` 的 `_bootstrapOhos`），
所以正常情况不用手敲。

> **命令行绕法**：直接跑 DevEco 给的那条 `hvigorw` 命令会连撞两个环境坑（都跟项目无关）：
> `DEVECO_SDK_HOME` 没设（DevEco Studio 会自己设，终端里不会），以及 `ohpm.bat` 爆栈
> （`BATCH RECURSION exceeds STACK limits`，Recursion Count=242）。
>
> 第二条的原因在 `ohpm.bat` 自己的 `:calculateFirstParamLen`：它按**首参数长度逐字符
> 递归**，首参数是脚本全路径时就递归到栈满。**这不是 Git Bash 特有的**——PowerShell
> 里一样会撞，只有 DevEco Studio 自己的调用方式不触发。
>
> 用仓库里的脚本绕开：

```bash
tool/sync_ohos.sh qfli_python            # 自动设 DEVECO_SDK_HOME + 装 ohpm shim + 补插件清单
tool/sync_ohos.sh qfli_python --no-daemon
tool/build_hap.sh qfli_python            # 直接出 HAP
```

> 脚本故意调 `hvigor.js` 而不是 `hvigorw.js`：后者会强制把 `ohpmBin` 覆盖回真正的
> `ohpm.bat`（`existsSync(e) && (process.env.ohpmBin = e)`），shim 就白做了。代价是
> 跳过了 wrapper 的 `initNodePath`（它负责把 `@ohos/hvigor-ohos-plugin` 放进解析路径），
> 所以**第一次 Sync 建议还是走 DevEco Studio**；等 `<app>/ohos/.hvigor/cache` 热了，
> 脚本就能稳定跑通。
>
> 两个脚本共用的环境准备在 `tool/lib/hvigor_env.sh`。
>
> 已接入的 App 都应使用这个脚本验证：`hvigor ERROR` 计数为 0，`:entry:init` 通过。

### 又一个「必须存在但被 gitignore 的文件」：`<app>/.flutter-plugins-dependencies`

在 DevEco 里跑 `assembleHap`，26 个 task 全过、`FlutterTask` 通过，最后卡在 ArkTS 编译：

```
10505001 ArkTS Compiler Error
Error Message: Cannot find module 'path_provider_ohos' or its corresponding type declarations.
At File: apps/qfli_python/ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets:2:32
COMPILE RESULT:FAIL {ERROR:2 WARN:280}
```

**别去查 `entry/oh-package.json5`**——能编过的 App 和编不过的 App，这个文件**逐字节相同**
（`"dependencies": {}`）。真正的输入是 App 目录下的插件清单，读它的是
`flutter-hvigor-plugin`：

```ts
const nativePlugins = findFlutterPlugins(
    path.join(flutterProjectPath, '.flutter-plugins-dependencies'))
nativePlugins.forEach(p => {
  overrides[p.name] = `file:${path.join(p.path, 'ohos')}`  // app 级 override
  dependenciesOpt[p.name] = ''                             // entry 级依赖
})
```

`hvigorconfig.ts` 传的是 `injectNativeModules(__dirname, path.dirname(__dirname))`，
即 `flutterProjectPath` = **App 目录**。所以缺文件 → 没有 override、没有依赖 →
ohpm 不会建 `entry/oh_modules/path_provider_ohos` 软链 → `GeneratedPluginRegistrant.ets`
里那句 import 解析不了。

**为什么会缺**：flutter 工具写的是
`File get flutterPluginsDependenciesFile => directory.childFile('.flutter-plugins-dependencies')`，
而 **pub workspace 模式下 `directory` 就是工作区根**（`flutter pub get` 的输出
`Got dependencies in D:\MyNewProjects\qflistudio` 就是证据），它不会给每个成员各写一份；
ohos 那条链也没有像 widget_preview / test 那样遍历 `workspaceProjects`。文件本身又被
`.gitignore` 忽略（生成物 + 本机绝对路径），所以**新克隆的仓库必然缺它**。

> `qfli_c` 之所以一直能编过，是因为它那份是 **2026-09-19 20:53** 生成的——那时它还没并进
> workspace，属于历史遗留侥幸。根目录那份和它**只差 `date_created`**，`ohos` 段完全一致，
> 因为所有 App 共用同一个 workspace、插件集合相同。

**修法**：把根目录那份复制到 App 目录（`sync_ohos.sh` / `build_hap.sh` 已自动做）：

```bash
cp .flutter-plugins-dependencies apps/qfli_python/.flutter-plugins-dependencies
tool/sync_ohos.sh qfli_python     # 重跑 Sync，重建 .hvigor/dependencyMap 与 oh_modules 软链
```

验证成功的标志：Sync 日志里出现 `:path_provider_ohos:init`（和 `qfli_c` 一样），
`entry/oh_modules/path_provider_ohos` 成为指向 pub cache 的软链。

**那 280 条 WARN 不用管**：全部落在 `oh_modules/.ohpm/@ohos+flutter_ohos@.../` 里
（`SendableJSONMessageCodec.ets`、`PathUtils.ets`、`FlutterPage.ets` 等），是 flutter_ohos
自己的代码，不是本仓库的。只有那 1 条 ERROR 是真问题。

---

## 九、已知限制与未验证项

**还没验证的**

- **鸿蒙签名与真机安装**：`apps/qfli_c/ohos/build-profile.json5` 的 `signingConfigs`
  是空的（现有 `.p7b` 绑的都是别的 bundleName），命令行能构建出
  `entry-default-unsigned.hap`，但装不上设备。首次构建前要在 DevEco 里自动生成签名，
  或去 AGC 为对应 bundleName 新建应用。详见 `c-app-and-harmonyos.md`。
- 已接入的 App 还没有全部在真机上跑过完整流程。
- **已验证 App 的 hvigor Sync 均通过**（`tool/sync_ohos.sh <app>`，`hvigor ERROR` 计数为 0，
  `:entry:init` 通过）。命令行 Sync 需要先设 `DEVECO_SDK_HOME` 并绕开 `ohpm.bat` 的递归，
  脚本已经处理好了。
- **`assembleHap` 只验到两个**：`qfli_web` 与 `qfli_python` 已 `BUILD SUCCESSFUL`
  （产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`，约 144 MB）。
  `qfli_java` 与 `qfli_dart` 停在 `:entry:default@FlutterTask`（`Error Code: 00308018`），
  原因未查——两者都是最后生成的两个 App，优先怀疑生成器在它们身上漏了什么，
  而不是 ohos 配置本身。

**设计上的限制**

- **交互式 stdin 不支持**。解释器是「先跑完再输出」的模型，所以约定用项目根目录的
  `input.txt` 一次性喂输入。要真正的交互式 stdin，得把解释器改成可挂起/可恢复的结构
  ——这是下一个量级的改造。
- **运行时长上限 10 秒**（另有 2 亿步兜底）。再往上放宽就要先做「输出实时推送」，
  否则程序超过十秒没动静，用户会以为卡住了。这两件事是绑在一起的。
- **鸿蒙上拉起系统浏览器**需要原生通道，目前 Web 版靠复制地址。
- **Python / Java / Dart / C++ / Lua 的解释器尚未完成**，这些 App 点运行会明确提示「解释器开发中」，
  不会给一个看起来像结果的假结果；离线 App 也不会因此调用在线服务。
