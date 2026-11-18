# Home Recovery And Compliance

- The home project tabs must follow `_ProjectScope` order and labels. All projects is the initial scope.
- Put project recycle bin, file recycle bin, file backups, and version history under the personal page's Data Management section. These local tools do not require login. Keep the home focused on projects and retain existing create/search actions; do not add recovery shortcut rows or replacement management buttons there.
- Hide the personal page's My Posts entry and published-content statistics. Do not fetch post counts for this page; retain profile refresh, points, and check-in information.
- `RecoveryPage` loads real ZIP archives through `RecycleBin.directory` and saved versions through `FileBackup.directory`. Backup settings use the persisted `SettingsStore.backupEnabled` switch.
- Recycle ZIPs and saved versions write a `.metadata.json` sidecar containing original path, project name, display name, and time. Existing records without metadata remain visible; recovery lets the user choose the destination.
- Version history groups by original path, falling back to project name plus basename for legacy records. The editor's version list filters metadata to avoid mixing files with equal basenames in different folders.
- Recycle recovery extracts to a staging directory, rejects absolute/escaping paths and symbolic links, and refuses to overwrite an existing destination. Project recovery registers the restored folder in `ProjectStore`.
- Restoring a version must successfully back up the current file before overwrite. Keep the saved record after restore; permanent deletion requires a separate confirmation.
- `ComplianceConfig` owns the APP ICP record and query URL. Display it at the end of the personal page, below logout, centered in subdued small text; keep it visible when logged out. Open the query using the existing in-app web page. Do not display an ICP footer on the project home page.
- Do not add or run tests unless requested. Static Dart analysis may be used without importing live backend database modules.
