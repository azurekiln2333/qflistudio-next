@echo off
rem ===========================================================================
rem  Remote computer agent launcher (companion\remote_agent).
rem
rem  Runs the Node agent that a paired phone drives through the relay. The
rem  agent is self-locating: this script works from any working directory.
rem
rem  Usage:
rem      companion\remote_agent\start.cmd                 (LAN relay, default)
rem      companion\remote_agent\start.cmd --relay wss://relay.example.com/ws
rem      companion\remote_agent\start.cmd --help
rem
rem  The script never installs silently: it runs `npm ci` only when the agent
rem  dependencies are absent. Chinese guidance lives in README.md here.
rem ===========================================================================
setlocal
cd /d "%~dp0"

node -e "const [a,b]=process.versions.node.split('.').map(Number);process.exit(a>23||(a===23&&b>=6)?0:1)" >nul 2>&1
if errorlevel 1 (
  echo Install Node.js 24 LTS, then run this launcher again.
  pause
  exit /b 1
)

if not exist node_modules\node-pty\package.json (
  echo Installing agent dependencies with npm ci ...
  call npm ci
  if errorlevel 1 (
    pause
    exit /b 1
  )
)

node src/agent/main.ts %*
set "agent_exit=%errorlevel%"
if not "%agent_exit%"=="0" pause
exit /b %agent_exit%
