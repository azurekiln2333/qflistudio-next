<#
.SYNOPSIS
    编译 libqfli_py.so（内嵌 MicroPython + NAPI 外壳）并放进 ohos/entry/libs/。

.DESCRIPTION
    一个命令把整条路走完：找工具链 → 配置 CMake → 编译 → 校验动态依赖 →
    拷贝到 ohos/entry/libs/<abi>/。之后用 DevEco 或 hvigor 打包 HAP 就行，
    不需要改任何 oh-package.json5。

    为什么要有这个脚本：以前 .so 是手工编好再手工拷进去的，别人（包括三个月
    后的自己）没法复现。这个脚本把「怎么编」固定下来，并且**在拷之前**就检查
    动态依赖——少一个 libc++_shared.so 这类问题，编译期完全看不出来，装到真机
    上才会以 "Cannot read property run of undefined" 的形式出现，非常难查。

    脚本不碰构建目录以外的东西：不带 -Clean 时不会删任何文件。

    每一步的完整输出都落在 native/build/cmake-<abi>/ 下：
    configure.log / build.log / check_so_deps.log。失败时打印尾部，
    剩下的去日志里看。

.PARAMETER Abi
    目标 ABI，默认 arm64-v8a（真机都是这个）。x86_64 用于模拟器。

.PARAMETER BuildType
    Release（默认）或 Debug。Debug 会带上完整符号表，.so 大很多，
    排查原生崩溃时用。

.PARAMETER Clean
    先删掉 native/build/cmake-<abi>/ 再重来。只在构建产物看起来不一致时用。

.PARAMETER DevEcoHome
    DevEco Studio 安装目录。默认读 $env:DEVECO_HOME，再退回常见安装路径。

.PARAMETER Python
    宿主 Python 3 的可执行文件。MicroPython 的 qstr 生成需要它。
    默认用 DevEco 自带的那个。

.PARAMETER SkipCopy
    只编译，不往 ohos/entry/libs/ 拷。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File apps\qfli_python\native\build.ps1

.EXAMPLE
    # 排查原生崩溃：带符号表编一份
    powershell -ExecutionPolicy Bypass -File apps\qfli_python\native\build.ps1 -BuildType Debug
#>
[CmdletBinding()]
param(
    [ValidateSet('arm64-v8a', 'x86_64', 'armeabi-v7a')]
    [string]$Abi = 'arm64-v8a',

    [ValidateSet('Release', 'Debug')]
    [string]$BuildType = 'Release',

    [switch]$Clean,
    [switch]$SkipCopy,

    [string]$DevEcoHome = '',
    [string]$Python = ''
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Fail([string]$Text) {
    Write-Host ""
    Write-Host "!! $Text" -ForegroundColor Red
    exit 1
}

<#
.SYNOPSIS
    跑一个外部工具，把 stdout/stderr 收进日志，返回退出码。

.DESCRIPTION
    不用 `& $exe` 直接调，原因是 `&` 在不同宿主里的行为不一致：正常交互式
    PowerShell 下它把输出流到控制台、退出码进 $LASTEXITCODE；但在一些被包装过
    的执行环境里（CI、精简 shell）两者都会丢，于是「命令到底跑没跑、跑成没跑成」
    完全看不出来。用 Start-Process 显式拿退出码 + 落盘日志，在哪都一样。

    代价是输出不再实时刷屏，而是在每步结束后打印尾部若干行。完整日志留在
    build\ 下，出错时能直接看。
#>
function Invoke-Tool {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$What
    )

    $errPath = "$LogPath.err"
    Remove-Item $LogPath, $errPath -ErrorAction SilentlyContinue

    # 手工拼命令行：Start-Process -ArgumentList 收数组时是用空格直接 join 的，
    # **不会**加引号。于是带空格的参数（本机 DevEco 装在
    # "D:\ProgramFiles\Huawei\DevEco Studio\..."）会被切成两半，报出来是
    # "Could not find toolchain file: D:\ProgramFiles\Huawei\DevEco" ——
    # 看着像路径写错了，其实是引号丢了。
    $argLine = ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '

    $proc = Start-Process -FilePath $Exe -ArgumentList $argLine -NoNewWindow -Wait `
        -PassThru -RedirectStandardOutput $LogPath -RedirectStandardError $errPath

    $lines = @()
    if (Test-Path $LogPath) { $lines += Get-Content $LogPath }
    if (Test-Path $errPath) {
        $errLines = Get-Content $errPath
        if ($errLines) { $lines += $errLines }
    }
    # 只打尾部：正常构建的输出有几百行，全打出来反而看不见重点。
    $tail = if ($lines.Count -gt 25) { $lines[-25..-1] } else { $lines }
    foreach ($line in $tail) { Write-Host "  $line" }

    return @{
        ExitCode = $proc.ExitCode
        Log      = $LogPath
        ErrLog   = $errPath
        Lines    = $lines.Count
    }
}

# 脚本自己所在目录 = apps/qfli_python/native
$NativeDir = $PSScriptRoot
$AppDir = Split-Path -Parent $NativeDir
$OhosDir = Join-Path $AppDir 'ohos'

Write-Host "QFLIStudio+ Python 原生后端构建" -ForegroundColor White
Write-Host "  native : $NativeDir"
Write-Host "  abi    : $Abi / $BuildType"

# ---------------------------------------------------------------------------
# 1. DevEco Studio / NDK
# ---------------------------------------------------------------------------
Write-Step "定位 DevEco Studio 与 NDK"

$candidates = @()
if ($DevEcoHome) { $candidates += $DevEcoHome }
if ($env:DEVECO_HOME) { $candidates += $env:DEVECO_HOME }
$candidates += 'D:\ProgramFiles\Huawei\DevEco Studio'
# 注意：这些环境变量在某些执行环境里可能是空的（比如从 CI / 精简 shell 里跑），
# 所以每个都要先判空再用 Join-Path——Join-Path 拿到 null 会直接抛。
if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles 'Huawei\DevEco Studio')
}
if (${env:ProgramFiles(x86)}) {
    $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Huawei\DevEco Studio')
}
if ($env:LOCALAPPDATA) {
    $candidates += (Join-Path $env:LOCALAPPDATA 'Huawei\DevEco Studio')
}

foreach ($cand in $candidates) {
    $ndk = Join-Path $cand 'sdk\default\openharmony\native'
    if (Test-Path (Join-Path $ndk 'build\cmake\ohos.toolchain.cmake')) {
        $DevEcoHome = $cand
        $Ndk = $ndk
        break
    }
}
if (-not $Ndk) {
    Fail @"
找不到 OpenHarmony NDK。找过这些位置：
$($candidates | ForEach-Object { "  - $_" } | Out-String)
用 -DevEcoHome <DevEco Studio 安装目录> 指定。
"@
}
Write-Host "  DevEco : $DevEcoHome"
Write-Host "  NDK    : $Ndk"

$CmakeBin = Join-Path $Ndk 'build-tools\cmake\bin'
$Cmake = Join-Path $CmakeBin 'cmake.exe'
$Ninja = Join-Path $CmakeBin 'ninja.exe'
$Toolchain = Join-Path $Ndk 'build\cmake\ohos.toolchain.cmake'

foreach ($tool in @($Cmake, $Ninja, $Toolchain)) {
    if (-not (Test-Path $tool)) { Fail "工具链缺文件：$tool" }
}

# ---------------------------------------------------------------------------
# 2. 宿主 Python 3
# ---------------------------------------------------------------------------
Write-Step "定位宿主 Python 3"

if (-not $Python) {
    $devEcoPy = Join-Path $DevEcoHome 'plugins\app-analyzer\lib\python\python.exe'
    if (Test-Path $devEcoPy) {
        $Python = $devEcoPy
    } else {
        $found = Get-Command python -ErrorAction SilentlyContinue
        if ($found) { $Python = $found.Source }
    }
}
if (-not $Python -or -not (Test-Path $Python)) {
    Fail @"
找不到 Python 3。生成 MicroPython 的 qstr 表需要它。
用 -Python <python.exe 路径> 指定，例如 DevEco 自带的：
  "$DevEcoHome\plugins\app-analyzer\lib\python\python.exe"
"@
}
Write-Host "  Python : $Python"

# ---------------------------------------------------------------------------
# 3. MicroPython 源码
# ---------------------------------------------------------------------------
Write-Step "检查 MicroPython 源码"

$MpDir = Join-Path $NativeDir 'third_party\micropython'
if (-not (Test-Path (Join-Path $MpDir 'py\makeqstrdefs.py'))) {
    Fail @"
MicroPython 源码不在位：$MpDir
先 clone 一份（README.md 里有完整命令），大致是：
  git clone --depth 1 https://github.com/micropython/micropython.git "$MpDir"
"@
}
Write-Host "  源码   : $MpDir"

# ---------------------------------------------------------------------------
# 4. 配置 + 编译
# ---------------------------------------------------------------------------
$BuildDir = Join-Path $NativeDir "build\cmake-$Abi"

if ($Clean -and (Test-Path $BuildDir)) {
    Write-Step "清理 $BuildDir"
    # 只删这一个目录（构建产物），不碰别的地方。删不掉时给一句能操作的提示，
    # 不要让它变成一个没有上下文的 PowerShell 红字。
    try {
        Remove-Item -Recurse -Force $BuildDir -ErrorAction Stop
    } catch {
        Fail @"
删不掉 $BuildDir：
  $($_.Exception.Message)

请手动删掉这个目录后重跑。它只装构建产物（CMake 缓存 + 目标文件），
删掉不会影响任何源码。
"@
    }
}

# 先把目录建出来：下面用 Start-Process 把日志重定向到 $BuildDir 下，
# 而重定向要求父目录已存在（cmake 自己会建目录，但那时已经太晚了）。
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

Write-Step "配置 CMake（$Abi / $BuildType）"
$configureArgs = @(
    '-G', 'Ninja',
    '-S', $NativeDir,
    '-B', $BuildDir,
    "-DCMAKE_TOOLCHAIN_FILE=$Toolchain",
    "-DOHOS_ARCH=$Abi",
    "-DCMAKE_BUILD_TYPE=$BuildType",
    "-DCMAKE_MAKE_PROGRAM=$Ninja",
    "-DQFLI_PY_PYTHON=$Python"
)
Write-Host "  $Cmake"
Write-Host "  $($configureArgs -join ' ')"

$configureLog = Join-Path $BuildDir 'configure.log'
# 配置期会顺带生成 MicroPython 的 qstr 表（native/micropython_embed/），
# 所以第一次会慢一些。
$configure = Invoke-Tool -Exe $Cmake -Arguments $configureArgs `
    -LogPath $configureLog -What 'cmake configure'

# 不只看退出码，也看产物：某些执行环境里退出码拿不到。
if ($configure.ExitCode -ne 0 -or
    -not (Test-Path (Join-Path $BuildDir 'build.ninja'))) {
    Fail @"
CMake 配置失败。
完整日志：$configureLog
$($configure.ErrLog)

常见原因：
  * 找不到宿主 Python 3 —— 用 -Python <python.exe> 指定
  * MicroPython 源码不在位 —— 见 native/README.md 的 clone 命令
"@
}

Write-Step "编译 libqfli_py.so"
Write-Host "  第一次要编一百多个 MicroPython 源文件，大约一两分钟；之后增量只要几秒。"

$buildLog = Join-Path $BuildDir 'build.log'
$build = Invoke-Tool -Exe $Cmake -Arguments @('--build', $BuildDir, '--target', 'qfli_py') `
    -LogPath $buildLog -What 'cmake build'

$BuiltSo = Join-Path $BuildDir 'libqfli_py.so'
if ($build.ExitCode -ne 0 -or -not (Test-Path $BuiltSo)) {
    Fail @"
编译失败。
完整日志：$buildLog
$($build.ErrLog)
"@
}

# ---------------------------------------------------------------------------
# 5. 校验动态依赖
# ---------------------------------------------------------------------------
# CMake 里已经有 POST_BUILD 检查，这里再显式跑一遍并打印清单，让「这个 .so
# 到底依赖什么」每次构建都看得见。
Write-Step "校验动态依赖"
$CheckScript = Join-Path $NativeDir 'tools\check_so_deps.py'
$checkLog = Join-Path $BuildDir 'check_so_deps.log'
$check = Invoke-Tool -Exe $Python -Arguments @($CheckScript, $BuiltSo) `
    -LogPath $checkLog -What 'check_so_deps'

if ($check.ExitCode -ne 0) {
    Fail @"
依赖检查没通过（见上面输出）。
这类问题的反馈周期是「装到真机才发现」，所以这里直接挡住。
最常见的原因是 C++ 标准库被动态链接了——CMakeLists 里必须保留
  target_link_libraries(qfli_py PUBLIC -static-libstdc++)
"@
}

# ---------------------------------------------------------------------------
# 6. 拷进构建路径
# ---------------------------------------------------------------------------
$LibsDir = Join-Path $OhosDir "entry\libs\$Abi"
$Target = Join-Path $LibsDir 'libqfli_py.so'

if ($SkipCopy) {
    Write-Step "跳过拷贝（-SkipCopy）"
    Write-Host "  产物：$BuiltSo"
} else {
    Write-Step "拷贝到 $LibsDir"
    if (-not (Test-Path $LibsDir)) {
        New-Item -ItemType Directory -Path $LibsDir -Force | Out-Null
    }
    Copy-Item -Path $BuiltSo -Destination $Target -Force
    $size = (Get-Item $Target).Length
    Write-Host ("  {0}  ({1:N0} 字节)" -f $Target, $size)
}

# ---------------------------------------------------------------------------
# 7. 下一步
# ---------------------------------------------------------------------------
$sizeKb = [math]::Round((Get-Item $BuiltSo).Length / 1KB)
Write-Host ""
Write-Host "完成。libqfli_py.so = $sizeKb KB（$Abi / $BuildType）" -ForegroundColor Green
Write-Host ""
Write-Host "接下来打包安装（在 $OhosDir 下）：" -ForegroundColor White
Write-Host "  1) DevEco Studio 里 Open 这个目录：$OhosDir   ← 注意是 ohos，不是 apps\qfli_python"
Write-Host "  2) 或者命令行："
Write-Host "     cd `"$OhosDir`""
Write-Host "     & `"$DevEcoHome\tools\hvigor\bin\hvigorw.bat`" assembleHap --mode module -p product=default"
Write-Host "  3) 装到设备时**认准 entry-default-signed.hap**。outputs\default\ 下同时留着"
Write-Host "     上一次的 entry-default-unsigned.hap，装它会报 code:9568320 no signature file。"
Write-Host ""
Write-Host "验证原生后端有没有真的加载（跑起来之后看日志）：" -ForegroundColor White
Write-Host "  hdc shell hilog -x | Select-String qfli_py"
Write-Host "  看到 MicroPython 版本号（形如 1.24.1）就是通了；"
Write-Host "  看到 'load libc++_shared.so failed' 就是依赖又出问题了，重跑本脚本。"
