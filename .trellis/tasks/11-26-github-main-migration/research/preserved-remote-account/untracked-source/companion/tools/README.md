# Cross-platform companion packaging

Studio's six desktop packages (windows/linux/macos × x64/arm64) need the remote
companion inside the app, otherwise the desktop "本机配对" page can only tell the
user to install Node themselves.

`package_companion.ps1` stages a self-contained bundle:

```
<out>/qfli-companion-<version>-<os>-<arch>/
  companion.json          # os, arch, node_version, agent_version, sandboxed
  node/                   # official Node runtime for <os>/<arch>
  package.json            # agent manifest (cloudterminal-server)
  src/                    # agent sources, unchanged
  node_modules/           # production deps, compiled for <arch>
  start.cmd | start.sh    # launcher used by the CLI fallback
  README.md               # user-facing pairing instructions
```

`verify_companion_bundle.mjs` then re-reads the staged binaries and fails the
build when the architecture does not match the target.

## Why the architecture is an explicit argument

`node-pty` is a native addon. Building the macOS **x64** app on an Apple
Silicon runner installs an **arm64** `pty.node`; the bundle then starts fine and
fails at the first terminal session on a user's Intel Mac. The packager
therefore never infers the target:

```bash
pwsh companion/tools/package_companion.ps1 \
  -Os macos -Arch x64 -NodeVersion 24.14.1 \
  -OutputDirectory build/ci-artifacts/qfli-companion-5.0.5-macos-x64
```

`-Arch` drives three things: the Node download (`darwin-x64`), the npm install
(`npm_config_arch`), and the post-install verification.

If the runner cannot produce that architecture, the script fails with the
mismatch instead of shipping a bundle that breaks later. Two documented ways
out, both root-coordinated:

1. Build the x64 package on an x64 runner (or under Rosetta with an x64 Node).
2. Keep the ARM build and ship the ARM bundle only with the arm64 package.

## macOS sandbox

Studio's macOS Release build has `app-sandbox` + `network.client` +
`network.server`, and a sandboxed app cannot spawn a bundled Node binary. The
bundle is still produced (it is needed for Windows/Linux and for users who launch
the companion themselves), and the Studio page falls back to a loopback attach:

1. User runs `start.sh` from the installed bundle location (documented in the
   page and in this README).
2. The launcher passes `--port-file <app support>/QFLIStudio/companion/sidecar.port`,
   so the sidecar writes only its loopback port there — never a token or secret.
3. Studio's desktop page reads that port and attaches to `127.0.0.1:<port>`.

That keeps the sandbox, keeps the GUI, and avoids pretending the sandbox can
spawn processes it cannot.

## Verifier as a CI gate

```bash
node companion/tools/verify_companion_bundle.mjs --bundle <dir>          # human
node companion/tools/verify_companion_bundle.mjs --bundle <dir> --json   # machine
```

Checks: required files, `companion.json` fields, Node binary architecture
(ELF/Mach-O/PE headers), every `node-pty` `.node` addon architecture, launcher
presence, absence of absolute development paths, and absence of credential or
environment files. Exit code 1 means the installer must not consume the bundle.
