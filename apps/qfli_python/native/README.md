# 原生执行后端（内嵌 MicroPython）

Python 版 App 的执行后端。**引擎是上游 MicroPython 1.24.1（commit `ecfdd5d`），
不是手写的解释器。**

```
Dart → MethodChannel('qfli_py/native') → ArkTS → libqfli_py.so → MicroPython
```

## 为什么是 MicroPython

一开始的设想是「应用内纯 Dart Python 子集解释器」，写了一半被否掉了，理由是兼容性：
手写一个子集要自己扛浮点语义、异常层次、生成器、f-string、迭代协议、描述符、
`__slots__`……每一项都是坑，而且「能跑一部分语法、细节上却跟真 Python 不一致」
对学习者是负价值。

MicroPython 自带完整的编译器 + 字节码 VM，语义跟 CPython 对得上，官方也提供了
`ports/embed` 这条**专门给宿主项目内嵌**的路线。所以选它。

这也回答了「为什么不能 exec 一个 python」：鸿蒙的普通应用被 SELinux 挡在 `exec` 之外，
既调不动设备上的解释器，也拉不起打包进 HAP 的可执行文件（HNP 那条路要求应用具备
生产力应用资格）。但沙箱从来不限制应用解释自己的数据——把源码交给**进程内**的 VM，
是普通应用唯一走得通的路。

### 怎么确认跑的是真的 MicroPython

`libqfli_py.so` 导出 `version()`，返回的字符串直接取自 MicroPython 自己的头文件
（`py/mpconfig.h` 的 `MICROPY_VERSION_STRING` + `genhdr/mpversion.h` 的
`MICROPY_GIT_HASH`），不是我们写的常量。App 里两个地方能看到它：

- 运行面板的标题：`运行 main.py（MicroPython 1.24.1 (ecfdd5d)）`
- App 启动时的 hilog 自检（见下）

**不想信上面的说法就自己验**（不用装任何东西，Python 标准库就够）：

```powershell
python apps\qfli_python\native\tools\inspect_so.py
```

它直接扫 `.so` 的字节，输出版本字符串、上游特征符号、动态依赖、未定义的 C++ 符号：

```
[2] 引擎身份（直接扫文件里的字符串，不是读配置）
    OK  版本号 1.24.1           命中 2 处
    OK  git hash ecfdd5d     命中 1 处
[3] 上游 MicroPython 特征符号
    OK  mp_hal_stdout_tx_strn
    OK  mp_execute_bytecode
    OK  nlr_push
...
结论：通过。依赖全是设备上一定有的系统库，引擎是上游 MicroPython。
```

`mp_execute_bytecode` / `nlr_push` 这些是 MicroPython 的字节码 VM 和异常展开器
自己的符号——手写的解释器不会有这些名字。

## 为什么需要 ArkTS 那一层

Flutter 的 Dart 代码不能直接调 NAPI，链路上必须有一个 ArkTS 环节。而 ArkTS 的
`import 'libqfli_py.so'` 是**构建期解析**的——`.so` 不在位，整个 App 直接编不过。

但反过来不成立：**编得过 ≠ 跑得起来**。见下面那节。

## ⚠️ 最大的一个坑：.so 的动态依赖

`.so` 是我们自己用 CMake 编的，**绕过了 hvigor 的 CMake 集成**。hvigor 只负责把
`ohos/entry/libs/<abi>/` 下的文件原样打进 HAP，它既不知道也不需要知道这个 `.so`
依赖了什么——**没有任何一步会去补齐它的依赖**。

所以只要链接时带上了一个非系统库，就会在真机上炸，而编译期一切正常：

```
W MUSL-LDSO: load libc++_shared.so failed, namespace=ndk no inherits, errno=2
W MUSL-LDSO: load libc++_shared.so failed, namespace=moduleNs_default, errno=2
W MUSL-LDSO: Error loading shared library libc++_shared.so:
             (needed by /data/storage/el1/bundle/libs/arm64/libqfli_py.so)
W MMG: [NMM:1439]key:default/qfli_py First: failed ... load module default/qfli_py failed
E ArkCompiler: [ecmascript] export objects of native so is undefined,
               so name is @app:com.azurekiln.qfli.pyflow/entry/qfli_py
```

最后一条的直接后果：ArkTS 里 `import qfliPyNative from 'libqfli_py.so'` 拿到
`undefined`，运行时报 **`Cannot read property run of undefined`**（退出码 1）。
从这条报错反推到「少了个 `.so`」非常费时间。

注意 `libc++_shared.so` **在设备上是存在的**（`/system/lib64/`），只是不在应用的
linker namespace 里，照样 errno=2。所以「设备上有这个库」不能作为依据。

**两道防线，现在都不会再漏：**

1. `CMakeLists.txt` 里 `target_link_libraries(qfli_py PUBLIC -static-libstdc++)`，
   等价于工具链的 `OHOS_STL=c++_static`（不能用 `-DOHOS_STL=c++_static` 代替：
   `ohos.toolchain.cmake` 里是 `set(OHOS_STL c++_shared)`，普通变量会盖住命令行
   传进来的同名缓存变量）。C++ 标准库静态链进来，`DT_NEEDED` 里就没有它了。
2. `tools/check_so_deps.py` 在**每次链接后**（CMake `POST_BUILD`）校验一遍
   `DT_NEEDED`，出现「HAP 里不会带的库」直接让构建失败。它用纯 Python 解析 ELF，
   不依赖 `llvm-readelf`。

## 目录

| 路径 | 作用 |
| --- | --- |
| `build.ps1` | **一键构建**：找工具链 → 配置 → 编译 → 校验依赖 → 拷进 `ohos/entry/libs/` |
| `CMakeLists.txt` | 构建 `libqfli_py.so`（两段式：先生成源码包，再编译） |
| `tools/build_embed.py` | 把 MicroPython 源码加工成自包含的 `micropython_embed/` 包 |
| `tools/check_so_deps.py` | 校验 `.so` 的动态依赖（纯 Python 解析 ELF，**构建期**守门） |
| `tools/inspect_so.py` | 事后复查：动态依赖 + 引擎身份 + 未定义 C++ 符号（**随时可跑**，见上） |
| `port/mpconfigport.h` | MicroPython 的 port 配置（特性档位、浮点、模块开关） |
| `port/mphalport.h` | port HAL 头：`input()` 的 `mp_hal_readline` 钩子 |
| `port/qstrdefsport.h` | port 自己的 qstr 定义（当前为空，但生成器要这个文件存在） |
| `port/qfli_time_localtime.c` | `time.localtime()` 的 port 钩子（**不是独立编译单元**） |
| `src/qfli_py_bridge.h` / `.c` | VM 生命周期 + 执行一次 + `qfli_py_version()`（纯 C，无平台依赖） |
| `src/qfli_py_hal.h` / `.c` | 输出捕获与标准输入（含 `sys.stdout` 走的 `mp_hal_*`） |
| `src/qfli_py_napi.cpp` | NAPI 外壳，把 `run()` / `version()` 暴露给 ArkTS |
| `ohos/QfliPyNative.ets` | ArkTS 接线模板（复制到 `ohos/entry/...` 才进构建） |
| `third_party/micropython/` | MicroPython 源码（clone 进来，不提交） |
| `micropython_embed/` | 生成物：自包含源码包（不提交） |

## 构建 .so

```powershell
powershell -ExecutionPolicy Bypass -File apps\qfli_python\native\build.ps1
```

它会自动找 DevEco Studio / NDK / 宿主 Python（DevEco 自带的那个），然后：

1. 配置 CMake 到 `native/build/cmake-arm64-v8a/`
2. 编译 `libqfli_py.so`（第一次要编一百多个 MicroPython 源文件，约一两分钟）
3. 校验动态依赖
4. 拷到 `ohos/entry/libs/arm64-v8a/libqfli_py.so`

每一步的完整日志落在 `native/build/cmake-arm64-v8a/` 下的
`configure.log` / `build.log` / `check_so_deps.log`，失败时脚本会打印尾部。

常用参数：`-BuildType Debug`（带符号表，排查原生崩溃用）、`-Abi x86_64`（模拟器）、
`-Clean`（重建）、`-SkipCopy`（只编译）、`-DevEcoHome` / `-Python`（路径不对时手动指）。

### 为什么不用上游的 `make`

本机**没有 `make`**，所以不走上游 `ports/embed/embed.mk`；`py/mkrules.cmake` 也不行
（它用 `cat`/`sed`/`touch`/管道/重定向，Ninja 在 Windows 上交给 cmd.exe 执行，一个都没有）。
`tools/build_embed.py` 用 Python 把同一套规则重做了一遍，由 CMake 在**配置期**调用
（改了 `port/*.h` 或 `tools/*.py` 时会自动重跑），也可以手动跑 `qfli_py_regen` 目标。

> `NATIVERENDER_ROOT_PATH` 不传也没关系：CMake 会丢掉空项，而 `napi/native_api.h`
> 是从 `--sysroot` 里的 `<ndk>/sysroot/usr/include/napi/` 找到的。

## 启用（两步，第一步 build.ps1 已经做了）

```bash
# 1. libqfli_py.so 已经在 ohos/entry/libs/arm64-v8a/ 下（build.ps1 拷的）

# 2. ArkTS 接线（已经接好了；换机器/新克隆时按这个做）
#    cp native/ohos/QfliPyNative.ets ohos/entry/src/main/ets/plugins/QfliPyNative.ets
#    然后在 EntryAbility.ets 的 configureFlutterEngine 里加：
#      import { registerQfliPyNativeChannel } from '../plugins/QfliPyNative';
#      registerQfliPyNativeChannel(flutterEngine)
```

**不需要**改 `oh-package.json5`。`ohos/entry/libs/<abi>/` 就是模块的 native 库目录，
hvigor 会自动打包（实测 `libs/arm64-v8a/libqfli_py.so` 出现在 HAP 里）。
Flutter 插件拷 `libapp.so` 用的也是这个目录。

打包时注意 DevEco 里 **Open 的必须是 `apps/qfli_python/ohos`**，不是 `apps/qfli_python`。

## 怎么确认后端通了

App 启动时（`registerQfliPyNativeChannel` 里）会跑一次自检，写进 hilog：

```powershell
hdc shell hilog -x | Select-String QfliPyNative
```

- 通了：能看到 `libqfli_py.so 已加载，MicroPython 1.24.1 (ecfdd5d)`，
  以及自检那次运行的输出（`sys.version` / `sys.implementation`）
- 没通：会看到 `libqfli_py.so 未加载：...`，里面写了原因和下一步
- 依赖又出问题：`hdc shell hilog -x | Select-String MUSL-LDSO`

## 实测过的证据（2026-09-20）

### 修复后这一版 `libqfli_py.so`（当前在 `ohos/entry/libs/arm64-v8a/` 里的）

`tools/inspect_so.py` 的完整输出：

| 检查 | 结果 |
| --- | --- |
| 大小 | 2,494,776 字节（静态链进 libstdc++ 之后变大，属预期） |
| SHA256 | `7FC8B8426292F53C72CA849F1FB87B78BC6C011444C78D3D28C9647DFC74B632` |
| `DT_NEEDED` | 只有 `libace_napi.z.so` / `libhilog_ndk.z.so` / `libc.so`，**非系统库 0 个** |
| 未定义 C++ 符号 | **0 个**（`.dynsym` 里 `SHN_UNDEF` 且 `_Z` 开头的） |
| 引擎身份 | 文件里搜到 `1.24.1`、`ecfdd5d`、`MicroPython` |
| 上游符号 | `mp_hal_stdout_tx_strn` / `mp_lexer_new_from_str_len` / `mp_execute_bytecode` / `nlr_push` / `gc_alloc` 全在 |
| 我们的导出 | `qfli_py_run` / `qfli_py_result_free` / `qfli_py_version` / `RegisterQfliPyNativeModule` 全在 |
| 模块名 | 与 ArkTS 请求的一致：设备日志 `key:default/qfli_py` |
| 模块注册 | `.init_array` 里确有 `R_AARCH64_ABS64 → RegisterQfliPyNativeModule` |
| 构建 | `build.ps1` 一次跑通，`check_so_deps.py` 在 POST_BUILD 通过 |

### 上一版（有 `libc++_shared.so` 的那版，仅作对照）

| 检查 | 结果 |
| --- | --- |
| hvigor 构建 | `BUILD SUCCESSFUL`，`CompileArkTS` 通过 |
| 签名 | `SignHap` 完成，产出 `entry-default-signed.hap` |
| 打包 | HAP 里有 `libs/arm64-v8a/libqfli_py.so`（464 KB，被 `DoNativeStrip` 剥过符号表） |
| 安装 | 设备上 `/data/storage/el1/bundle/libs/arm64/libqfli_py.so` 在位 |
| **运行** | **失败**：`MUSL-LDSO` → `import` 拿到 `undefined` → `Cannot read property run of undefined` |

这两张表放在一起正好说明那节标题的意思：**编得过、签得出、装得上，全都不能保证跑得起来。**

> **装的时候认准 `entry-default-signed.hap`。** 同目录下还有一个
> `entry-default-unsigned.hap`（上一次未签名的残留），装它会报
> `code:9568320 error: no signature file`。

> **待补**：修复后的 `.so` 重新打包、装机、`hilog` 自检这条链路还没跑过
> （本机沙箱里 `hvigor` 的 `ohpm install` 出不去网，`wmic.exe` 也被策略挡了，
> 造不出 HAP）。跑完把结果补到这张表里。

## 已知限制

- **交互式 stdin 不支持。** 模型是「先跑完再输出」，`input()` 从一次性喂进去的
  缓冲区里按行取。约定：项目根目录放 `input.txt`。要做真交互得把执行改成
  可挂起/可恢复的状态机。
- **没有文件系统。** `open()` / `io.open()` 一律 `OSError: [Errno 2] ENOENT`，
  `import` 只找内置模块。
- **只出 `arm64-v8a`。** 要覆盖 32 位设备得再加 `armeabi-v7a`，安装包体积翻倍。

## 维护注意

改这几处时容易漏掉另一半，都是**会静默出错**或**报错指向别处**的类型：

1. **`EXTMOD_MODULES` 里加模块** → 三件事要同时成立：`.c` 进包、`.c` 进 qstr 扫描列表、
   `mpconfigport.h` 里对应的 `MICROPY_PY_XXX` 打开。缺了只会在运行时
   `ModuleNotFoundError`。`REQUIRED_MODULES` 会替你挡住常见的漏。
2. **`CMakeLists.txt` 的排除列表** → `lib/re1.5/*.c` 和 `port/qfli_time_localtime.c`
   是「只被文本包含、不单独编译」的文件，从 glob 里排除了。新增这类文件要一起加。
3. **`CMakeLists.txt` 的 `-static-libstdc++` 不能删。** 删掉就回到上面那个
   `libc++_shared.so` 的坑，而且只有真机才炸。`check_so_deps.py` 会挡住，
   但如果连它一起删了就没人管了。
4. **`native/ohos/QfliPyNative.ets` 和 `ohos/entry/src/main/ets/plugins/QfliPyNative.ets`
   是两份逐字节相同的副本**，改逻辑要一起改。前者不在构建路径里，**漂了不会有任何
   编译错误或测试失败**，所以只能靠哈希查：

   ```powershell
   Get-FileHash apps\qfli_python\native\ohos\QfliPyNative.ets,
     apps\qfli_python\ohos\entry\src\main\ets\plugins\QfliPyNative.ets -Algorithm MD5
   ```

   两份必须一致（复制即可，不用手改）。通道协议（`available` 返回
   `{available, version, detail}`）两边不一致时，`python_runner.dart` 里有兼容分支
   兜底，但那只是兜底，不是可以不管。
5. **`python_runner.dart` 的 `heapKb`** 要和 `qfli_py_bridge.c` 的
   `QFLI_PY_DEFAULT_HEAP_KB` 保持一致。
6. **终端里 App 自己的诊断行都带 `[qfli] ` 前缀**（见 `python_runner.dart` 的
   `_appPrefix`）。不加前缀的话，后端没跑起来时满屏中文提示会被误认成
   「Python 输出是中文」。新增诊断行要沿用这个前缀。

生成器里写了几处**主动校验**（`_verify_modules` / `_verify_qstrs`），因为它们对应的
失败都是静默的。踩过的坑：`MICROPY_FLOAT_IMPL` 没设 → `import math` 直接不存在；
qstr 表丢了 95% → 生成的表里仍有 165 条静态 qstr，看起来「有内容」。
详见 `tools/build_embed.py` 和 `port/` 下各文件的注释。
