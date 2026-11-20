param(
  [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
  [Parameter(Mandatory = $true)][string]$CrtDirectory,
  [Parameter(Mandatory = $true)][string]$Dumpbin,
  [Parameter(Mandatory = $true)][ValidateSet('x64', 'arm64')][string]$Architecture,
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$RedistVersion
)

$ErrorActionPreference = 'Stop'
# Inspect native exit codes explicitly so a crash includes the binary and tool.
$PSNativeCommandUseErrorActionPreference = $false
$releaseRoot = (Resolve-Path -LiteralPath $ReleaseDirectory).Path
$crtRoot = (Resolve-Path -LiteralPath $CrtDirectory).Path
$dumpbinPath = (Resolve-Path -LiteralPath $Dumpbin).Path
$packageBase = "QFLIStudioN-$Version-windows-$Architecture"
$packageWork = [System.IO.Path]::GetFullPath((Join-Path $env:RUNNER_TEMP 'package'))
$packageRoot = Join-Path $packageWork $packageBase
if (Test-Path -LiteralPath $packageWork) {
  throw "Package destination already exists: $packageWork"
}
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
Get-ChildItem -LiteralPath $releaseRoot -Force | Copy-Item -Destination $packageRoot -Recurse

# Keep link-time outputs outside the portable package and the installer.
Get-ChildItem -LiteralPath $packageRoot -File | Where-Object {
  $_.Extension -in @('.lib', '.exp', '.pdb', '.ilk')
} | ForEach-Object {
  Write-Output "Dropping link-time file $($_.Name)"
  Remove-Item -LiteralPath $_.FullName
}

Write-Output "Bundling $Architecture CRT $RedistVersion from $crtRoot"
foreach ($runtime in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
  $source = Join-Path $crtRoot $runtime
  if (Test-Path -LiteralPath $source -PathType Leaf) {
    Copy-Item -LiteralPath $source -Destination $packageRoot
  } elseif ($runtime -eq 'vcruntime140_1.dll') {
    Write-Output "Note: $crtRoot holds no $runtime for $Architecture"
  } else {
    throw "$crtRoot holds no required $runtime"
  }
}

# Every MSVC runtime DLL imported by a packaged executable or DLL must exist.
$binaries = Get-ChildItem -LiteralPath $packageRoot -File | Where-Object {
  $_.Extension -in @('.exe', '.dll')
} | Sort-Object Name
if (!$binaries) { throw "No Windows binaries in $packageRoot" }
foreach ($binary in $binaries) {
  Write-Output "Inspecting $($binary.FullName) with $dumpbinPath -nologo -dependents"
  $report = @(& $dumpbinPath -nologo -dependents $binary.FullName 2>&1)
  $toolExitCode = $LASTEXITCODE
  $reportPath = Join-Path $env:RUNNER_TEMP "pe-dependents-$($binary.Name).txt"
  $report | Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM
  Write-Output "dumpbin exit=$toolExitCode binary=$($binary.Name) report=$reportPath"
  if ($toolExitCode -ne 0) {
    $report | ForEach-Object { Write-Output $_ }
    throw "dumpbin failed for $($binary.FullName): exit $toolExitCode; tool=$dumpbinPath"
  }
  if ($report.Count -eq 0) { throw "dumpbin returned no output for $($binary.FullName)" }
  foreach ($line in $report) {
    if ([string]$line -match '^\s*([A-Za-z0-9_.-]+\.dll)\s*$') {
      $dependency = $Matches[1]
      if ($dependency -match '^(msvcp|vcruntime|concrt|vccorlib|vcomp)') {
        if (!(Test-Path -LiteralPath (Join-Path $packageRoot $dependency) -PathType Leaf)) {
          throw "$($binary.Name) imports $dependency, which is missing from the package"
        }
        Write-Output "PASS $($binary.Name) -> $dependency"
      }
    }
  }
}

Get-ChildItem -LiteralPath $packageRoot | Format-Table Name, Length
"vc_runtime=bundled msvcp140.dll and vcruntime140.dll from redistributable $RedistVersion" |
  Add-Content -LiteralPath (Join-Path $env:RUNNER_TEMP 'windows-build-info.txt') -Encoding utf8NoBOM
@(
  "PACKAGE_BASE=$packageBase",
  "PACKAGE_WORK=$($packageWork.Replace('\', '/'))"
) | Add-Content -LiteralPath $env:GITHUB_ENV -Encoding utf8NoBOM
