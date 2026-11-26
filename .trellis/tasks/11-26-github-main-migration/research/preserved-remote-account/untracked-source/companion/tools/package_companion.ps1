# Stages a self-contained remote-companion bundle for one Studio desktop target.
#
# Usage (Windows / macOS / Linux, PowerShell 7+):
#   pwsh companion/tools/package_companion.ps1 `
#     -Os windows -Arch x64 -NodeVersion 24.14.1 `
#     -OutputDirectory build/ci-artifacts/qfli-companion-5.0.5-windows-x64
#
# Parameters:
#   -Os            windows | macos | linux        (required)
#   -Arch          x64 | arm64                    (required)
#   -NodeVersion   exact version, e.g. 24.14.1    (required)
#   -OutputDirectory                              (required)
#   -AgentDir      companion/remote_agent         (default: script-relative)
#   -AgentVersion  stamped into companion.json    (default: from package.json)
#   -SkipDownload  reuse an already downloaded archive (checksum still verified)
#
# Steps:
#   1. Downloads the official Node runtime for the *target* os/arch and checks it
#      against nodejs.org's published SHASUMS256.txt (reused archives too).
#   2. Copies the agent sources by enumeration (never a wildcard path, which
#      `Copy-Item -LiteralPath` does not expand): sources, relay-core.json, and
#      no identity/bootstrap/env file.
#   3. Installs production dependencies with npm_config_arch pinned to the
#      target, so native addons compile for the consumer, not the runner.
#   4. Writes companion.json, the launcher (start.cmd / start.sh) and README.
#   5. Runs verify_companion_bundle.mjs, which re-reads the binaries and fails
#      the build on any architecture mismatch.
#
# It never installs into the source tree, never reads or copies credentials, and
# never touches the original CloudTerminal checkout.

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('windows', 'macos', 'linux')][string]$Os,
  [Parameter(Mandatory = $true)][ValidateSet('x64', 'arm64')][string]$Arch,
  [Parameter(Mandatory = $true)][string]$NodeVersion,
  [Parameter(Mandatory = $true)][string]$OutputDirectory,
  [string]$AgentDir = '',
  [string]$AgentVersion = '',
  [switch]$SkipDownload
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # .../studio
if ([string]::IsNullOrWhiteSpace($AgentDir)) {
  $AgentDir = Join-Path $repoRoot 'companion/remote_agent'
}
$AgentDir = (Resolve-Path -LiteralPath $AgentDir).Path
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

# --- target naming ----------------------------------------------------------

# Node's distribution suffix per target. Kept explicit: a wrong suffix here
# silently produces a bundle for the build host instead of the consumer.
$nodePlatform = switch ($Os) {
  'windows' { 'win' }
  'macos' { 'darwin' }
  'linux' { 'linux' }
}
$archiveExt = if ($Os -eq 'windows') { 'zip' } else { 'tar.gz' }
$nodeFolder = "node-v$NodeVersion-$nodePlatform-$Arch"
$archiveName = "$nodeFolder.$archiveExt"
$distUrl = "https://nodejs.org/dist/v$NodeVersion"

if ([string]::IsNullOrWhiteSpace($AgentVersion)) {
  $AgentVersion = (Get-Content -LiteralPath (Join-Path $AgentDir 'package.json') -Raw | ConvertFrom-Json).version
}

Write-Host "== packaging companion for $Os/$Arch (Node $NodeVersion, agent $AgentVersion)"

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$bundleName = "qfli-companion-$AgentVersion-$Os-$Arch"
$bundleDir = [System.IO.Path]::GetFullPath((Join-Path $OutputDirectory $bundleName))

<#
  Guard recursive deletion: the target must be a direct child of the output
  directory and must carry the bundle prefix. A malformed -OutputDirectory must
  never turn into `Remove-Item -Recurse` somewhere else on disk.
#>
function Assert-SafeBundlePath {
  param([string]$Target, [string]$Root, [string]$Name)
  $rootWithSeparator = $Root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
  if (-not $Target.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "refusing to modify ${Target}: not inside $Root"
  }
  if ((Split-Path -Parent $Target) -ne $Root.TrimEnd([System.IO.Path]::DirectorySeparatorChar)) {
    throw "refusing to modify ${Target}: not a direct child of $Root"
  }
  if (-not $Name.StartsWith('qfli-companion-')) {
    throw "refusing to modify ${Target}: unexpected bundle name $Name"
  }
  if ($Target -eq $Root) { throw 'refusing to modify the output directory itself' }
}

Assert-SafeBundlePath -Target $bundleDir -Root $OutputDirectory -Name $bundleName
if (Test-Path -LiteralPath $bundleDir) {
  Write-Host "   replacing $bundleDir"
  Remove-Item -LiteralPath $bundleDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $bundleDir | Out-Null

# --- 1. Node runtime for the target ----------------------------------------

$downloadDir = Join-Path $OutputDirectory '.downloads'
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
$archivePath = Join-Path $downloadDir $archiveName

function Get-ExpectedSha256 {
  param([string]$Name)
  $sumsPath = Join-Path $downloadDir 'SHASUMS256.txt'
  if (-not (Test-Path -LiteralPath $sumsPath)) {
    Invoke-WebRequest -Uri "$distUrl/SHASUMS256.txt" -OutFile $sumsPath -UseBasicParsing
  }
  $line = Get-Content -LiteralPath $sumsPath |
    Where-Object { $_ -match "\s\*?$([regex]::Escape($Name))$" } |
    Select-Object -First 1
  if (-not $line) { throw "SHASUMS256.txt has no entry for $Name" }
  return ($line -split '\s+')[0]
}

# The expected digest is resolved on every run, including -SkipDownload: a
# reused archive is exactly as untrusted as a fresh download.
$expectedSha = Get-ExpectedSha256 -Name $archiveName
if ($SkipDownload -and (Test-Path -LiteralPath $archivePath)) {
  Write-Host "   reusing $archiveName (verifying checksum)"
} else {
  Write-Host "   downloading $archiveName"
  Invoke-WebRequest -Uri "$distUrl/$archiveName" -OutFile $archivePath -UseBasicParsing
}
$actualSha = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha -ne $expectedSha.ToLowerInvariant()) {
  throw "Node archive checksum mismatch for $archiveName`: expected $expectedSha, got $actualSha"
}

$extractDir = Join-Path $downloadDir 'extract'
if (Test-Path -LiteralPath $extractDir) {
  $extractDir = [System.IO.Path]::GetFullPath($extractDir)
  $downloadDirFull = (Resolve-Path -LiteralPath $downloadDir).Path
  Assert-SafeBundlePath -Target $extractDir -Root $downloadDirFull -Name 'qfli-companion-extract'
  Remove-Item -LiteralPath $extractDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
if ($archiveExt -eq 'zip') {
  Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir -Force
} else {
  tar -xzf $archivePath -C $extractDir
  if ($LASTEXITCODE -ne 0) { throw "tar failed to extract $archiveName" }
}

$nodeSource = Join-Path $extractDir $nodeFolder
if (-not (Test-Path -LiteralPath $nodeSource)) { throw "extracted Node folder not found: $nodeSource" }
$nodeTarget = Join-Path $bundleDir 'node'
New-Item -ItemType Directory -Force -Path $nodeTarget | Out-Null
# Enumerate: `Copy-Item -LiteralPath *` treats the star as a literal name.
Get-ChildItem -LiteralPath $nodeSource -Force | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $nodeTarget -Recurse -Force
}

# --- 2. agent sources -------------------------------------------------------

# Anything machine-local stays out of the bundle: identity, bootstrap config,
# installed dependencies, caches and VCS metadata.
$excluded = @(
  'node_modules', '.git', 'dist', 'build', '.dart_tool',
  'agent.json', 'bootstrap.json', 'cloudterminal.bootstrap.json', '.env',
  '.npmrc', '.DS_Store', 'Thumbs.db'
)
Get-ChildItem -LiteralPath $AgentDir -Force | Where-Object { $excluded -notcontains $_.Name } | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $bundleDir -Recurse -Force
}

# relay-core.json records the provenance of the five synchronised relay files.
# It must ship with the agent: the bundle is not auditable without it.
if (-not (Test-Path -LiteralPath (Join-Path $bundleDir 'relay-core.json'))) {
  throw 'relay-core.json was not staged; the bundle would lose its relay provenance'
}

# --- 3. dependencies for the target architecture ---------------------------

<#
  Install with the **target** Node runtime and its own bundled npm, not the
  runner's global npm.

  Why: `npm_config_arch` only paraphrases the request. node-gyp still compiles
  with the host toolchain, so an Apple Silicon runner asked for x64 through
  global npm produces an arm64 `pty.node` inside an x64 bundle — the failure this
  whole script exists to prevent. Running the downloaded x64 Node (`node/bin/node
  node/lib/node_modules/npm/bin/npm-cli.js`) under Rosetta makes every build step
  — compiler probe, target detection, install target — genuinely x64.

  `npm ci` still needs the lockfile inside the bundle: `package-lock.json` is
  copied with the agent sources above.
#>
$bundleNode = Join-Path $nodeTarget ($(if ($Os -eq 'windows') { 'node.exe' } else { 'bin/node' }))
if (-not (Test-Path -LiteralPath $bundleNode)) {
  throw "target Node runtime missing after copy: $bundleNode"
}
$bundleNpmCli = Join-Path $nodeTarget $(if ($Os -eq 'windows') {
    'node_modules/npm/bin/npm-cli.js'
  } else {
    'lib/node_modules/npm/bin/npm-cli.js'
  })
if (-not (Test-Path -LiteralPath $bundleNpmCli)) {
  throw "target npm missing in the Node distribution: $bundleNpmCli"
}

# Belt and braces: keep the arch hint too, for addons whose install script only
# reads it. It does not replace using the target runtime.
$env:npm_config_arch = $Arch
$env:npm_config_target_arch = $Arch
$env:npm_config_omit = 'dev'
$taskPreviousPath = $env:PATH
$env:PATH = (Split-Path -Parent $bundleNode) + [IO.Path]::PathSeparator + $taskPreviousPath
Push-Location $bundleDir
try {
  Write-Host "   installing production dependencies with the $Arch Node runtime"
  # On macOS an x64 Node only runs through Rosetta; let the shim report the real
  # error instead of silently falling back to the host architecture.
  & $bundleNode $bundleNpmCli ci --omit=dev --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) {
    throw @"
npm ci failed for $Os/$Arch using the bundled $Arch Node.
On macOS, an x64 Node requires Rosetta 2:  softwareupdate --install-rosetta --agree-to-license
Do not fall back to the runner's global npm: it builds native addons for the host.
"@
  }
} finally {
  Pop-Location
  $env:PATH = $taskPreviousPath
  Remove-Item Env:npm_config_arch -ErrorAction SilentlyContinue
  Remove-Item Env:npm_config_target_arch -ErrorAction SilentlyContinue
  Remove-Item Env:npm_config_omit -ErrorAction SilentlyContinue
}

# The staged Node runtime is for the consumer, not a dependency source: drop the
# npm tree so the bundle carries only the interpreter (saves ~15 MB and keeps
# the bundle's own package manager out of reach of the agent).
$nodeNpmTree = Join-Path $nodeTarget $(if ($Os -eq 'windows') { 'node_modules' } else { 'lib/node_modules' })
if (Test-Path -LiteralPath $nodeNpmTree) {
  Remove-Item -LiteralPath $nodeNpmTree -Recurse -Force
}

# --- 4. manifest, launcher, readme -----------------------------------------

$manifest = [ordered]@{
  component = 'remote_companion'
  os = $Os
  arch = $Arch
  node_version = $NodeVersion
  agent_version = $AgentVersion
  # macOS keeps the app sandbox: Studio cannot spawn this bundle itself, so the
  # desktop page attaches to a companion the user launched.
  sandboxed = ($Os -eq 'macos')
  agent_dir = 'companion/remote_agent'
  entry = 'src/agent/main.ts'
  pair_link_scheme = 'cloudterminal://pair'
  # Attaching (rather than spawning) requires the credential published next to
  # the loopback port; a port alone is not an identity.
  attach = [ordered]@{
    mode = 'token'
    port_file = 'sidecar.json'
    file_mode = '0600'
    token_bytes = 24
    handshake = 'first-frame {"type":"auth","token":"..."}'
  }
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $bundleDir 'companion.json') -Encoding utf8NoBOM

if ($Os -eq 'windows') {
  $startCmd = @'
@echo off
rem Pair with your phone using the one-time code printed below.
rem The same code is also printed as a cloudterminal://pair?... link you can copy.
rem
rem --port-file publishes {port, token} with owner-only permissions so the
rem desktop app can attach to this companion. The token is the attach credential;
rem it is never the device secret or a pairing code.
setlocal
cd /d "%~dp0"
set "PORT_FILE=%APPDATA%\QFLIStudio\companion\sidecar.json"
if not exist "%APPDATA%\QFLIStudio\companion" mkdir "%APPDATA%\QFLIStudio\companion" >nul 2>&1
"%~dp0node\node.exe" src\agent\main.ts --sidecar --console-pairing --port-file "%PORT_FILE%" %*
if errorlevel 1 pause
'@
  Set-Content -LiteralPath (Join-Path $bundleDir 'start.cmd') -Value ($startCmd -replace "`r`n", "`r`n") -Encoding ascii
} else {
  # POSIX launcher. The attach path must match what the Studio locator reads:
  # macOS uses the shared Application Support directory (the sandboxed app may
  # read it), Linux uses XDG_CONFIG_HOME.
  $startSh = @'
#!/bin/sh
# Pair with your phone using the one-time code printed below.
# The same code is also printed as a cloudterminal://pair?... link you can copy.
#
# --port-file publishes {port, token} with owner-only permissions so the desktop
# app can attach to this companion. The token is the attach credential; it is
# never the device secret or a pairing code.
set -eu
cd "$(dirname "$0")"
case "$(uname -s)" in
  Darwin)
    port_file="$HOME/Library/Application Support/QFLIStudio/companion/sidecar.json"
    ;;
  *)
    config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    port_file="$config_home/QFLIStudio/companion/sidecar.json"
    ;;
esac
mkdir -p "$(dirname "$port_file")"
chmod 700 "$(dirname "$port_file")" 2>/dev/null || true
# --console-pairing prints the code and the pair link for a person at a terminal.
# The attach token is never printed: it only goes into the 0600 port file.
exec ./node/bin/node src/agent/main.ts --sidecar --console-pairing --port-file "$port_file" "$@"
'@
  Set-Content -LiteralPath (Join-Path $bundleDir 'start.sh') -Value ($startSh -replace "`r`n", "`n") -Encoding utf8NoBOM
  if (Get-Command chmod -ErrorAction SilentlyContinue) {
    & chmod 755 (Join-Path $bundleDir 'start.sh')
  }
}

$launcherName = if ($Os -eq 'windows') { 'start.cmd' } else { './start.sh' }
$readme = @"
# QFLIStudio remote companion ($Os/$Arch)

This bundle drives the Studio *本机配对* page and the phone's remote-computer view.

- Start it: `$launcherName`
- The one-time pairing code and the `cloudterminal://pair?...` link are printed
  in the terminal; press Enter for a new code.
- The attach token is never printed. The launcher passes `--console-pairing`;
  Studio's own launchers omit it, so their stdout carries only JSON frames.
- Nothing here needs to be installed: the bundle carries its own Node runtime.
- `relay-core.json` records the provenance of the five synchronised relay files.

## Attaching instead of spawning

The companion publishes `{ "port": N, "token": "..." }` to
`~/.config/QFLIStudio/companion/sidecar.json` (Windows:
`%APPDATA%\QFLIStudio\companion\sidecar.json`), mode 0600 inside a 0700
directory. A desktop app that attaches to an already-running companion must
read that file and send `{"type":"auth","token":"..."}` as its first frame.
The port alone is never accepted as identity.

The token is a per-run attach credential. It is not the device secret and it is
never a pairing code; do not copy it into logs or bug reports.

macOS keeps the app sandbox. If the Studio window says the companion was not
found, run `$launcherName` from this folder and press *连接本机 companion* in the
desktop page: it attaches through the port file above without spawning Node.
"@
Set-Content -LiteralPath (Join-Path $bundleDir 'README.md') -Value $readme -Encoding utf8NoBOM

# --- 5. verification -------------------------------------------------------

$verifier = Join-Path $repoRoot 'companion/tools/verify_companion_bundle.mjs'
Write-Host '   verifying bundle'
node $verifier --bundle $bundleDir
if ($LASTEXITCODE -ne 0) {
  throw "bundle verification failed for $Os/$Arch; the installer must not consume $bundleDir"
}

Write-Host "== bundle ready: $bundleDir"
