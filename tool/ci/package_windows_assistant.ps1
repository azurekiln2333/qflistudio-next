param(
  [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
  [Parameter(Mandatory = $true)][string]$OutputDirectory,
  [Parameter(Mandatory = $true)][string]$NodeVersion
)

$ErrorActionPreference = 'Stop'
$appRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$releaseRoot = (Resolve-Path $ReleaseDirectory).Path
$packageRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $packageRoot) {
  throw "Package destination already exists: $packageRoot"
}
foreach ($relative in @('cloudterminal_windows.exe', 'flutter_windows.dll', 'data/app.so', 'data/icudtl.dat')) {
  $required = Join-Path $releaseRoot $relative
  if (!(Test-Path -LiteralPath $required -PathType Leaf) -or (Get-Item -LiteralPath $required).Length -eq 0) {
    throw "Missing assistant build output: $relative"
  }
}
New-Item -ItemType Directory -Path $packageRoot | Out-Null
Copy-Item -Path (Join-Path $releaseRoot '*') -Destination $packageRoot -Recurse

# A standalone Flutter Windows bundle needs the redistributable CRT DLLs.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsRoot = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1).Trim()
if (!$vsRoot) { throw 'Visual Studio C++ tools are unavailable.' }
$crt = Get-ChildItem -Path (Join-Path $vsRoot 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT') -Directory |
  Where-Object { (Test-Path (Join-Path $_.FullName 'msvcp140.dll')) -and (Test-Path (Join-Path $_.FullName 'vcruntime140.dll')) } |
  Sort-Object FullName -Descending | Select-Object -First 1
if (!$crt) { throw 'The x64 MSVC redistributable directory is unavailable.' }
Copy-Item -Path (Join-Path $crt.FullName '*.dll') -Destination $packageRoot

# Bundle the official Node runtime so users need no development toolchain.
$nodeName = "node-v$NodeVersion-win-x64"
$archiveName = "$nodeName.zip"
$nodeArchive = Join-Path $env:RUNNER_TEMP "assistant-$archiveName"
$manifest = (Invoke-WebRequest -Uri "https://nodejs.org/dist/v$NodeVersion/SHASUMS256.txt").Content
$checksumLine = $manifest -split '\r?\n' | Where-Object { $_ -match ('\s+' + [regex]::Escape($archiveName) + '$') }
if (@($checksumLine).Count -ne 1) { throw 'Node archive checksum is missing or ambiguous.' }
$expectedNodeHash = ($checksumLine -split '\s+')[0].ToLowerInvariant()
Invoke-WebRequest -Uri "https://nodejs.org/dist/v$NodeVersion/$archiveName" -OutFile $nodeArchive
if ((Get-FileHash -LiteralPath $nodeArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedNodeHash) {
  throw 'Node runtime checksum mismatch.'
}
$nodeExtract = Join-Path $env:RUNNER_TEMP 'assistant-node-runtime'
Expand-Archive -LiteralPath $nodeArchive -DestinationPath $nodeExtract
$runtime = Join-Path $packageRoot 'runtime'
New-Item -ItemType Directory -Path $runtime | Out-Null
Copy-Item -LiteralPath (Join-Path $nodeExtract "$nodeName/node.exe") -Destination $runtime
Copy-Item -LiteralPath (Join-Path $nodeExtract "$nodeName/LICENSE") -Destination (Join-Path $runtime 'NODE-LICENSE.txt')
$node = Join-Path $runtime 'node.exe'
if ((& $node --version) -ne "v$NodeVersion") { throw 'Bundled Node version mismatch.' }

# Copy source and locked production dependencies, never a developer identity.
$source = Join-Path $appRoot 'companion/remote_agent'
$agent = Join-Path $packageRoot 'remote_agent'
New-Item -ItemType Directory -Path $agent | Out-Null
foreach ($item in @('src', 'scripts', 'package.json', 'package-lock.json', 'README.md', 'start.cmd', 'start.sh')) {
  Copy-Item -LiteralPath (Join-Path $source $item) -Destination $agent -Recurse
}
$env:PATH = "$runtime;$env:PATH"
Push-Location $agent
try {
  & npm.cmd ci --omit=dev
  if ($LASTEXITCODE -ne 0) { throw 'Installing packaged agent dependencies failed.' }
  # Run the packaged runtime and source over a real loopback relay. The provider
  # is scripted and does not contact Claude or load any user credentials.
  & $node scripts/e2e.ts --demo --timeout 60
  if ($LASTEXITCODE -ne 0) { throw 'Packaged companion protocol E2E failed.' }
} finally {
  Pop-Location
}

@'
@echo off
setlocal
cd /d "%~dp0"
set "CLOUDTERMINAL_NODE=%~dp0runtime\node.exe"
set "CLOUDTERMINAL_AGENT_DIR=%~dp0remote_agent"
set "PATH=%~dp0runtime;%PATH%"
start "" "%~dp0cloudterminal_windows.exe"
'@ | Set-Content -LiteralPath (Join-Path $packageRoot 'Start-QFLI-Remote.cmd') -Encoding ascii

@'
QFLIStudio Remote Computer Assistant for Windows x64

Extract the entire archive to a writable directory.
Open Start-QFLI-Remote.cmd to start the assistant.
Use the pairing code or link in QFLIStudio's Remote Computer screen.

This package includes Flutter, Node.js and the agent's production dependencies.
Flutter, Node.js, npm and Visual Studio do not need to be installed separately.
Herdr, Claude and Codex remain optional tools installed by the user.
Tool sessions use the user's own accounts and require their own authentication.

The launcher preserves the existing agent identity in ~/.cloudterminal.
No developer identity or credential is included in this archive.
The package is unsigned. No physical-device validation has been performed.
Third-party license notices are retained with the runtime and dependencies.
'@ | Set-Content -LiteralPath (Join-Path $packageRoot 'README.txt') -Encoding utf8NoBOM
Copy-Item -LiteralPath (Join-Path $appRoot 'LICENSE') -Destination $packageRoot

$facts = @(
  'component=windows-assistant',
  "app_version=$env:APP_VERSION",
  "app_commit=$env:GITHUB_SHA",
  "core_commit=$env:QFLI_CORE_COMMIT",
  "flutter_version=$env:QFLI_FLUTTER_VERSION",
  "flutter_commit=$(& git -C $env:QFLI_FLUTTER_ROOT rev-parse HEAD)",
  "node_version=$NodeVersion",
  "node_archive_sha256=$expectedNodeHash",
  "msvc_redist=$($crt.Parent.Parent.Name)",
  'architecture=x64',
  'build_mode=release',
  'signing=unsigned',
  'packaged_protocol_e2e=passed',
  'device_validation=none',
  "run=$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
)
$facts | Set-Content -LiteralPath (Join-Path $packageRoot 'BUILD_INFO.txt') -Encoding utf8NoBOM
$checksums = Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
  $relative = [System.IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace('\', '/')
  "$(($_ | Get-FileHash -Algorithm SHA256).Hash.ToLowerInvariant())  $relative"
}
[System.IO.File]::WriteAllText(
  (Join-Path $packageRoot 'SHA256SUMS'),
  (($checksums -join "`n") + "`n"),
  [System.Text.UTF8Encoding]::new($false)
)
Write-Output "Packaged Windows assistant: $packageRoot"
