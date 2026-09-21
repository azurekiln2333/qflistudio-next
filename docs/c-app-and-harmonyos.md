# 语言专属 App 与鸿蒙上的本地编译

记录「一个语言做一个 App」这个方向在 HarmonyOS 上到底能做到哪一步，以及 C 版是怎么落地的。

## 结论先说

- **在鸿蒙上跑「真编译器」这条路，普通应用走不通。** 应用沙箱的 SELinux 策略禁止普通应用
  `exec` 任意 ELF，打包在 HAP 里的可执行文件也拉不起来。
- **官方给的口子是 HNP（OpenHarmony Native Package）**，但它面向「生产力应用」，
  普通应用拿不到这个资格。
- **能走通的是「在应用进程内解释执行」**——沙箱限制的是「执行别的程序」，
  从来不限制「应用解释自己的数据」。C 版就是按这个思路做的。
- **不需要每个语言一个包。** 按语言切 App 对 C/C++ 是切错的，正确的切法是按**工具链**切：
  C 可以配一个极小的 tcc，C 和 C++ 共用一个 clang。

## 为什么不能直接跑编译器

鸿蒙的应用沙箱对「执行文件」这件事管得很死。普通应用把一个 ELF 放进自己的沙箱目录、
再 `chmod 755` 调起来，会在 `hilog` 里看到：

```
avc: denied { execute } for path="/data/storage/el2/base/haps/entry/files/gcc"
  scontext=... tcontext=... tclass=file permissive=0
```

关键在 `avc: denied` —— 这是 **SELinux 策略层**的拒绝，不是文件权限。所以
`chmod 755` 没用，改文件所有者也没用，只能改系统策略，而那是应用改不了的东西。

想绕开的话，官方给的正规通道是 **HNP**：

1. 用 `hnpcli` 把二进制打成 `.hnp` 包；
2. 放进 HAP 的 `hnp/<ABI>/` 目录；
3. 在 `module.json5` 里声明 `hnpPackages`；
4. 运行时用 `system()` / `execv()` 把它拉起来。

但 HNP 的文档明确是给**生产力应用**用的，普通应用不具备这个资格。所以对
「上架一个普通 App」这个前提，HNP 不是可选项。

> 结论：**不要在这条路上继续投入**。设备上没有可用的 gcc/clang，也不能自带一个。

## 走通的方案：进程内解释

沙箱不限制应用解释自己的数据。所以把 C 源码读进内存、在应用进程里做完
「预处理 → 词法 → 语法 → 解释执行」，全程不写可执行文件、不起子进程，就能拿到
和「本地跑起来了」一样的用户体验。

C 版实现了两个这样的后端：

| | Dart 解释器（默认交付） | picoc（可选） |
| --- | --- | --- |
| 位置 | `packages/qfli_c_runtime` | `apps/qfli_c/native` |
| 语言 | 纯 Dart | C + NAPI |
| 需要 NDK | 否 | 是 |
| 每 ABI 一份 `.so` | 否 | 是 |
| 可测性 | 63 个用例，`flutter test` 直接跑 | 只能上真机验 |
| 执行速度 | 慢 | 快 |

默认走 Dart 解释器，因为它在所有平台都能跑、能被 CI 覆盖，而且教学规模的程序
（几十到几千行）速度完全够用。picoc 作为「想要更快」时的可选升级路径保留，
接线方式见 [`apps/qfli_c/native/README.md`](../apps/qfli_c/native/README.md)。

### Dart 解释器覆盖了什么

不是玩具子集，是能正经写作业的覆盖面：

- **预处理**：`#include`（系统头 + 项目内头文件）、对象式/函数式宏、`#` / `##`、
  `#if` / `#ifdef` / `#elif` / `#else` / `#endif`、`#pragma once`、`#error`、
  `__FILE__` / `__LINE__`，错误能定位回**原始文件原始行**
- **类型**：`int` / `char` / `short` / `long` / 无符号族 / `float` / `double`、
  指针、数组、多维数组、`struct` / `union` / `enum` / `typedef`、函数指针、
  位域除外的 LP64 布局（`sizeof(long) == 8`，和 arm64 真机一致）
- **控制流**：`if` / `while` / `do-while` / `for` / `switch`（含穿透）/ `goto` / 标签
- **标准库**：`printf` 全格式（含 `*` 宽度、`%g`、指数补零）、`scanf` 家族、
  `puts` / `putchar` / `getchar` / `fgets`、`str*` / `mem*`、`malloc` / `calloc` /
  `realloc` / `free`、`atoi` / `strtol` / `strtod`、`math.h` 全套、`ctype.h` 全套、
  `rand` / `srand`（LCG 与 C 一致，结果可复现）、`time` / `clock`、`assert`
- **多文件**：项目里所有 `.c` 各自当独立翻译单元编译，共享函数表——
  等价于一次「没有链接器的链接」，`main.c` 能直接调 `utils.c` 里的函数

### 工程上的两个决定

**一、源码用 GBK 也能读。** 中文用户从 Windows 记事本存出来的 `.c` 是 GBK，
直接按 UTF-8 读会崩。运行时按 BOM → 严格 UTF-8 校验 → GBK 的顺序猜编码。

**二、程序跑飞了要有兜底，但不能误杀正常程序。** 两个上限各管一件事：

- **墙钟时间上限（默认 10 秒）**——真正拦住死循环的那个。手机上解释器比桌面慢
  3~5 倍，10 秒约合桌面上 2~3 秒的计算量。
- **步数上限（默认 2 亿步）**——与设备速度无关的确定性兜底，只在时间控制失效时生效。

为什么不只用步数：同一个步数在两类程序上差 **20 倍**时间。实测紧凑循环约
**2800 万步/秒**，递归调用只有 **120 万步/秒**（每次调用要新建作用域）。
早先的 800 万步上限对紧凑循环只够跑 0.3 秒——`for (int i = 0; i < 3000000; i++)`
这种正常的百万级循环会被误报成死循环。

**三、缺输入不能只说「死循环」。** 程序读 `scanf` 却拿不到输入时会在原地空转，
和死循环的表现几乎一样，但这是新手最常踩的坑。运行时统计「读到空输入」的次数
（`stdinStarvedReads`），在超时错误后面补一句真正的原因。还有一种更隐蔽的情况：
程序拿着 0 值算完了，退出码 0、结果看起来正常但其实是错的——这种情况走
**中性的 `warnings` 通道**而不是报错，因为 `while (scanf(...) == 1)` 这种写法本身没错。

## 多语言 App 该怎么切

> 这一节是早期的切分讨论。**实际落地的方案和五个语言的现状见
> [`multi-language-apps.md`](./multi-language-apps.md)**——最终没有走「配 tcc/clang」这条路，
> 因为鸿蒙普通应用 exec 不了任何可执行文件，只能走进程内解释。

「一个语言一个 App」这个直觉对 C/C++ 是切错的。真正决定体积和复杂度的不是语言，
是**工具链**：

- **C 单独一个包，配 tcc。** tcc 是 C-only 编译器，约 1 MB 量级，比 clang 小一个数量级。
- **C 和 C++ 共用一个包，配 clang。** clang 本来就是 C/C++/ObjC 共用的一个 driver，
  拆成两个包只会把同一份 clang 塞两遍。

所以合理的切法是：

| 包 | 后端 | 说明 |
| --- | --- | --- |
| `qfli_c` | Dart 解释器（+ 可选 picoc） | 本文档描述的这个 |
| `qfli_cpp` | 和 C 共用 clang | 建议和 C 合成一个「C/C++」包 |
| `qfli_python` | 应用内 Dart 解释器 | 已建 App，解释器待写 |

## 工程结构

仓库用 **Dart pub workspace** 组织：一次 `pub get` 解析全部子包，共用一份 `pubspec.lock`。

```
pubspec.yaml                 根：workspace 声明 + 唯一的 dependency_overrides
packages/qfli_studio_core/   共享 IDE 内核（编辑器、文件树、主题、项目管理、教程加载）
packages/qfli_c_runtime/     C 解释器（预处理/词法/语法/执行 + 标准库）
apps/qfli_c/                 C 版 App（薄壳 + C 档位 + 平台工程）
apps/qfli_web/               Web 版（不需要解释器，走内核的本地静态服务器）
apps/qfli_python/            Python 版（解释器待写）
apps/qfli_java/              Java 版（解释器待写）
apps/qfli_dart/              Dart 版（解释器待写）
tool/new_language_app.dart   从 apps/qfli_c 生成新的语言 App
```

五个 App 的现状、各自的运行后端与路线图见
[`multi-language-apps.md`](./multi-language-apps.md)。

内核不关心自己在给哪门语言用。语言差异全部收敛到 `StudioProfile`：

```dart
StudioProfile.current = const StudioProfile(
  id: 'c',
  appTitle: 'QFLIStudio+ C 版',
  templates: [ProjectTemplate.empty, ProjectTemplate.c],  // 新建项目只出这两个
  runner: CProgramRunner(),                                // 运行按钮交给 C 运行时
  entryFileNames: ['main.c', 'src/main.c'],                // 优先命中 C 入口
);
```

在 `runApp` 之前设一次，同一个 UI 就收窄成了 C 专用产品：新建项目只出现 C 模板、
首页语言筛选芯片只剩 C、运行按钮走应用内解释器。加一门语言 = 加一个 App 目录，
内核一行不用改。

## 构建

```bash
# 依赖（workspace 一次解析全部子包）
flutter pub get

# 全量静态检查
flutter analyze

# 测试：内核 71 个 + C 运行时 73 个 + C 版接线 25 个
(cd packages/qfli_studio_core && flutter test)
(cd packages/qfli_c_runtime     && flutter test)
(cd apps/qfli_c                 && flutter test --no-pub)
# ↑ apps/ 下的包必须加 --no-pub：它们带 ohos/ 平台目录，不加会先做一遍全平台工具链
#   校验，本机没有 HarmonyOS SDK 就报 No Hmos SDK found 并退出 1，一个用例都不跑。
#   看着像测试挂了，其实是环境检查没过。packages/ 下的包没有 ohos/，不加也能跑。
#
# 其余四个语言 App（qfli_web / qfli_python / qfli_java / qfli_dart）同样要加
# --no-pub，测试数与整体现状见 multi-language-apps.md。

# 鸿蒙（命令行，见下）
```

## 在 DevEco 里构建

**Open 的目录是 `apps/qfli_c/ohos`，不是 `apps/qfli_c`。** DevEco 认的是 ohos 这一层
（`hvigorfile.ts` / `build-profile.json5` 在这里）。选错了会提示"不是 HarmonyOS 工程"。

### 前提：两个被 gitignore 掉的文件

> **新生成的 App（`tool/new_language_app.dart`）这两件事都由生成器代劳了**，
> 它还会顺手跑 `npm install` + `ohpm install`。下面这段是手工排查时看的。

`ohos/.gitignore` 里有 `/local.properties` 和 `/package.json`，这两个文件**在全新克隆里
是不存在的**，但构建必须有。它们平时由 flutter 工具生成，而生成它的那一步
（`installHvigorPlugin`）排在 `updateLocalProperties` 之后——后者找不到 HarmonyOS SDK
就抛 `No Hmos SDK found` 直接退出，所以**在本机这条自动生成链路是断的**，得手工补：

```bash
cd apps/qfli_c/ohos

# 1) local.properties —— hvigor 插件靠它读 flutter.sdk
cat > local.properties <<'EOF'
hwsdk.dir=D:\ProgramFiles\Huawei\DevEco Studio\sdk
flutter.sdk=D:\ProgramFiles\flutter_ohos
EOF

# 2) package.json —— hvigorconfig.ts 靠它解析 flutter-hvigor-plugin
cat > package.json <<'EOF'
{
  "dependencies": {
    "flutter-hvigor-plugin": "file:D:\\ProgramFiles\\flutter_ohos\\packages\\flutter_tools\\hvigor"
  }
}
EOF

# 3) 装依赖（离线可解，只装这一个本地包）
npm install --no-audit --no-fund
```

> 两个文件里都是**本机绝对路径**，所以不该提交；换个开发机要重新生成。
> 少了 `local.properties`，hvigor 插件读不到 `flutter.sdk`，会去找不存在的引擎 har；
> 少了 `package.json`，报 `Cannot find module 'flutter-hvigor-plugin'`。

### Sync 要完成的两件事

1. `npm install` —— 装 `flutter-hvigor-plugin`。**缺了它，构建报
   `Cannot find module 'flutter-hvigor-plugin'`**（就是上面那个文件的问题）。
2. `ohpm install` —— 解析 `@ohos/hypium` 这类 ohpm 依赖，产出 `ohos/oh_modules/`。

Sync 完直接点 Run 即可。真正干活的是 `hvigorfile.ts` 里挂的
`flutterHvigorPlugin(path.dirname(__dirname))`：它在 entry 上注册一个
`default@FlutterTask`，先调 `flutter assemble -dTargetPlatform=ohos -dBuildMode=debug`
编出 Dart 产物，再把 `flutter_assets` 拷到
`entry/src/main/resources/rawfile/`、把 `libapp.so` 拷到 `entry/libs/<abi>/`。
所以**不需要手动跑 `flutter build hap`**，也不需要在 DevEco 里配什么 Flutter 路径——
插件自己从 `ohos/local.properties` 读 `flutter.sdk`。

### 构建前必须先处理签名

`ohos/build-profile.json5` 的 `signingConfigs` 是**空的**，这是有意的，不是漏配：

- HarmonyOS 的 `.p7b` 描述文件**绑定 bundleName**。`D:/Keystore` 下现有的三个描述文件
  分别属于 `com.azurekiln.qflistudio`（`qfliRelease.p7b` / `qfli_profileDebug.p7b`）和
  `com.azurekiln.terminax`，**没有一个是 `com.azurekiln.qflistudio.c`**。
- 主工程的密钥库叫 `suanxiwanjie.p12`，别名 `suanxiwanjie`。

所以二选一：

| 路线 | 做法 | 结果 |
| --- | --- | --- |
| **A（推荐）** | File → Project Structure → Signing Configs → 勾 `Automatically generate signature`（需登录华为账号） | DevEco 为当前 bundleName 生成一套材料并自动写回 `build-profile.json5` |
| B | 在 AGC 里为 `com.azurekiln.qflistudio.c` 新建应用，重新生成证书和描述文件 | 手工把 `material` 填回去 |

不配签名也能构建，但产出 `entry-default-unsigned.hap`，**装不上设备**。
临时图快也可以把 `AppScope/app.json5` 的 bundleName 改回 `com.azurekiln.qflistudio`，
立刻能用主工程那套签名——代价是两个 App 互相覆盖安装。

### 命令行

`apps/qfli_c/ohos` 里**没有 `hvigorw` 包装脚本**（主工程也没有，这个模板就不带）。
命令行构建要用 DevEco 自带的那份，而且**要绕过它自带的 ohpm**：

```bash
# 1) 做一个 ohpm 代理脚本（DevEco 自带的 ohpm.bat 在受限环境下会自我递归）
#    内容见下面「为什么要绕」
cat > "$TEMP/ohpm-shim/ohpm.bat" <<'EOF'
@echo off
node "D:\ProgramFiles\Huawei\DevEco Studio\tools\ohpm\bin\pm-cli.js" %*
EOF

# 2) 直接调 hvigor.js（不是 hvigorw.bat，原因见下）
cd apps/qfli_c/ohos
export NODE_HOME="D:\ProgramFiles\Huawei\DevEco Studio\tools\node"
export DEVECO_SDK_HOME="D:\ProgramFiles\Huawei\DevEco Studio\sdk"
export ohpmBin="$TEMP\\ohpm-shim\\ohpm.bat"
export PATH="$TEMP/ohpm-shim:$NODE_HOME:$PATH"

"$NODE_HOME/node.exe" \
  "D:/ProgramFiles/Huawei/DevEco Studio/tools/hvigor/hvigor/bin/hvigor.js" \
  --mode module -p product=default assembleHap --no-daemon
```

实测结果：`BUILD SUCCESSFUL in 41 s`，42 个任务全跑，产出
`entry/build/default/outputs/default/entry-default-unsigned.hap`（约 138 MB）。

**为什么要绕两层：**

1. DevEco 自带的 `tools/ohpm/bin/ohpm.bat` 在受限环境（Git Bash + 沙箱）下会自我递归，
   报 `BATCH RECURSION exceeds STACK limits / Recursion Count=242`，连 `ohpm.bat -v`
   都跑不过。它本身只是个 node 启动器，所以直接调底层的 `pm-cli.js` 就行。
2. **`hvigorw.js` 会把 `ohpmBin` 强行覆盖掉**——它有这段：
   `const e = resolve(__dirname, "../../ohpm/bin/", isWindows() ? "ohpm.bat" : "ohpm");
   existsSync(e) && (process.env.ohpmBin = e)`。
   所以设了环境变量也没用，必须绕开 `hvigorw.bat` 直接调 `hvigor.js`。

在 DevEco 里构建不需要这些——IDE 用的是自己的进程和参数传递，不走这条批处理路径。

**debug 构建没有 `libapp.so` 是正常的。** 插件只在非 debug 模式才拷 `app.so`；
debug 走 JIT，产物是 `rawfile/flutter_assets/kernel_blob.bin`。


## 当前验证到哪一步

| 项 | 状态 |
| --- | --- |
| `flutter analyze`（全仓） | 干净 |
| 内核测试 | 60 / 60 通过 |
| C 运行时测试 | 73 / 73 通过 |
| C 版接线测试 | 25 / 25 通过 |
| 鸿蒙构建（`hvigor`） | **已通过**——`BUILD SUCCESSFUL in 41s`，产出 `entry-default-unsigned.hap`（138 MB） |
| 鸿蒙**签名安装** | **未验证**——需要先配签名，见上面「构建前必须先处理签名」 |
| 真机运行 | **未验证**——没有设备/模拟器 |
| 原生 picoc 后端编译 | **未验证**——需要 NDK，见 `native/README.md` |

构建产物核对过：`pack.info` 里 bundleName 是 `com.azurekiln.qflistudio.c`、
`compatible 18 / target 24`、`deviceType ["phone"]`；`rawfile/flutter_assets/`
里有 `kernel_blob.bin`，说明 hvigor 插件的 `flutter assemble` + 拷贝链路是通的。
debug 构建没有 `libapp.so` 属正常（只有 profile/release 才拷）。

## 已知限制与下一步

1. **交互式 stdin 不支持。** 解释器是「先跑完再输出」的模型，`scanf` / `getchar`
   拿到的是一次性输入。当前约定：项目根目录放 `input.txt`，内容即标准输入。
   具体影响（都不是报错，是行为变形）：

   | 写法 | 现在的结果 |
   | --- | --- |
   | 交互式问答（猜数字、菜单） | 输入必须**事先全部写进 `input.txt`**，程序不能根据上一次的回答决定下一次问什么 |
   | 提示语 `printf("请输入：")` | 不带 `\n` 就不显示——输出是跑完才推送的，用户看不到提示 |
   | 未知长度输入（`while (scanf(...) == 1)`） | 只能按 `input.txt` 的行数写死，没法真的「输到不想输为止」 |
   | 「按任意键继续」 | 退化成一次普通读取，没有「按键」这个概念 |
   | 忘了放 `input.txt` | 程序拿着 0 值继续算，结果**看起来正常但是错的**；终端里给一条中性提示 |

   要真正的交互式 stdin，得把解释器改成可挂起/可恢复的结构——这是下一个量级的改造，
   也是目前最值得做的一件事。它至少牵动四件事：解释器要有事件循环、同步的 `_eval`
   树里要能 `await` 通道往返、输出要改成增量刷新、`execute()` 大概率要重写成状态机。
   建议第一版只给 Dart 后端做——picoc 没有协程，挂起它要动 C 侧的执行栈。

   实测最坏的一种（不检查 `scanf` 返回值，也就是新手最常见的写法）：没有 `input.txt`
   时程序不会退出，而是拿着 0 原地空转，1 秒内刷出 **312076 行**「小了」才被时间上限拦住。
   在真终端里同样的代码会停在光标处等你输入——这就是「一次性输入」和「交互式输入」
   的全部差别。
2. **C++ 没做。** `apps/qfli_c` 明确不接管 `.cpp`（有测试覆盖这个行为）。
   按上面的分析，C++ 应该和 C 共用一个 clang 包，而不是各做一个。
3. **调试器没有。** 没有断点、单步、变量监视。教学场景里这个的优先级低于 stdin。
4. **`fscanf` 只认 stdin。** 没有真正的 `FILE*` 文件语义。
