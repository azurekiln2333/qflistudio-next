# Embedded server disposition

The app no longer owns the embedded `azurekiln-qfli-server/` checkout.
The existing 77 deletions are retained as the repository split.

- Original app subtree: `fd5041973d954031abeaaadd6ed1d3e7f70f9994:azurekiln-qfli-server`.
- Split branch: `f4d5bb7007f9`, unrelated app-root history. Do not merge it at the app root.
- Independent repository: `azurekiln2333/azurekiln-qfli-server`.
- Independent GitHub main verified with `ls-remote` on 2026-11-26: `d919a91990615f17310391d0e84ba0cdb77c8ffa`.
- The four newer embedded changes at app `c5f4bc3afe9c81ba488fd3f544d43c3dac061512` only replace the product label `QFLIStudio+` with `QFLIStudioN`. They affect README.md, package.json description, src/routes/auth.js callback text and src/server.js comment.
- These branding changes are recorded here for the server owner. They do not change behavior and do not justify resurrecting the duplicate server tree. Original versions remain in app Git history.

No independent server repository was modified by the app migration.
