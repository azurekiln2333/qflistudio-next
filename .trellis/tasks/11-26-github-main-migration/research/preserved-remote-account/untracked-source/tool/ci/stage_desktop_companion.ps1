# Stage the target companion where the installed Studio locator expects it.
# This runs only on CI; it downloads Node and builds native dependencies.
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('windows', 'linux', 'macos')][string]$Os,
  [Parameter(Mandatory = $true)][ValidateSet('x64', 'arm64')][string]$Arch,
  [Parameter(Mandatory = $true)][string]$NodeVersion,
  [Parameter(Mandatory = $true)][string]$AppVersion,
  [Parameter(Mandatory = $true)][string]$Destination
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$taskBuild = [IO.Path]::GetFullPath((Join-Path $taskRepo 'build'))
$taskDestination = [IO.Path]::GetFullPath($Destination)
$taskComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$taskPrefix = $taskBuild.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $taskDestination.StartsWith($taskPrefix, $taskComparison)) {
  throw 'Companion staging destination must stay inside this checkout build directory'
}
if (Test-Path -LiteralPath $taskDestination) {
  throw "Companion staging requires a fresh destination: $taskDestination"
}

$taskOutput = Join-Path $taskBuild "companion-staging/$Os-$Arch"
& (Join-Path $taskRepo 'companion/tools/package_companion.ps1') `
  -Os $Os -Arch $Arch -NodeVersion $NodeVersion -AgentVersion $AppVersion `
  -OutputDirectory $taskOutput
$taskBundle = Join-Path $taskOutput "qfli-companion-$AppVersion-$Os-$Arch"
if (-not (Test-Path -LiteralPath (Join-Path $taskBundle 'companion.json'))) {
  throw "Companion packager did not produce $taskBundle"
}

if ($Os -eq 'macos') {
  # Keep the Studio sandbox intact. Finder starts this separate companion app.
  $taskResources = Join-Path $taskDestination 'Contents/Resources/companion'
  $taskExecutables = Join-Path $taskDestination 'Contents/MacOS'
  New-Item -ItemType Directory -Path $taskResources, $taskExecutables -Force | Out-Null
  Get-ChildItem -LiteralPath $taskBundle -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $taskResources -Recurse
  }
  $taskLauncher = @'
#!/bin/sh
set -eu
cd "$(dirname "$0")/../Resources/companion"
exec ./start.sh
'@
  $taskEntry = Join-Path $taskExecutables 'qfli-remote-companion'
  [IO.File]::WriteAllText($taskEntry, ($taskLauncher -replace "`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))
  $taskPlist = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.azurekiln.qflistudio.remote-companion</string>
<key>CFBundleName</key><string>QFLI Remote Companion</string>
<key>CFBundleExecutable</key><string>qfli-remote-companion</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$AppVersion</string>
<key>CFBundleVersion</key><string>$AppVersion</string>
<key>LSUIElement</key><true/>
</dict></plist>
"@
  [IO.File]::WriteAllText((Join-Path $taskDestination 'Contents/Info.plist'), $taskPlist, [Text.UTF8Encoding]::new($false))
  & chmod 755 $taskEntry (Join-Path $taskResources 'start.sh')
  if ($LASTEXITCODE -ne 0) { throw 'Could not mark companion launchers executable' }
  & codesign --force --deep --sign - $taskDestination
  if ($LASTEXITCODE -ne 0) { throw 'Companion ad-hoc signing failed' }
  & codesign --verify --deep --strict $taskDestination
  if ($LASTEXITCODE -ne 0) { throw 'Companion signature verification failed' }
} else {
  New-Item -ItemType Directory -Path $taskDestination -Force | Out-Null
  Get-ChildItem -LiteralPath $taskBundle -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $taskDestination -Recurse
  }
}
Write-Host "Staged $Os/$Arch companion at $taskDestination"
