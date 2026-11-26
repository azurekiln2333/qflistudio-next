$ErrorActionPreference = 'Stop'
$taskRoot = 'D:/MyNewProjects/qflistudio/.trellis/tasks/11-20-cloudterminal-import'
$reportRoot = Join-Path $taskRoot 'reports'
$env:TRELLIS_CONTEXT_ID = 'pi-cloudterminal-import-20261120'
$env:PI_OFFLINE = '1'
$env:PYTHONUTF8 = '1'
Set-Location -LiteralPath 'D:/MyNewProjects/_wt/cloudterminal-import/work/qfli_studio_core'
$nodeExe = (Get-Command node -ErrorAction Stop).Source
$cliEntry = 'D:/AppData/Roaming/npm/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js'
$piArgs = @('--print','--mode','json','--no-extensions','--no-mcp','--session-dir',(Join-Path $reportRoot 'pi-sessions'),'--name','CloudTerminal migration','--tools','read,bash,powershell,edit,write,grep,find,ls',('@' + (Join-Path $taskRoot 'pi-brief.md')),'Implement the authorized task. Read the attached brief and task artifacts. Keep the original source untouched.')
$run = [ordered]@{provider='pi';name='CloudTerminal migration';pid=$PID;started_at=(Get-Date -Format o);cwd=(Get-Location).Path;status='running';session_dir=(Join-Path $reportRoot 'pi-sessions');stdout=(Join-Path $reportRoot 'pi-output.jsonl');stderr=(Join-Path $reportRoot 'pi-stderr.log')}
$run | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $reportRoot 'dispatch.json') -Encoding utf8
try {
  & $nodeExe $cliEntry @piArgs 1> (Join-Path $reportRoot 'pi-output.jsonl') 2> (Join-Path $reportRoot 'pi-stderr.log')
  $run['exit_code'] = $LASTEXITCODE
  $run['status'] = if ($LASTEXITCODE -eq 0) {'exited'} else {'failed'}
} catch {
  $run['status'] = 'failed'
  $run['error'] = $_.Exception.Message
} finally {
  $run['ended_at'] = Get-Date -Format o
  $run | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $reportRoot 'dispatch.json') -Encoding utf8
}
