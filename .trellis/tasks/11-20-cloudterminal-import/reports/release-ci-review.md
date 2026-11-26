# Release CI review

Read-only audit on 2026-11-20 (Asia/Shanghai). No build, test, device command, credential extraction, push, tag, or source workspace mutation was performed. This report is the only written artifact.

## Baselines and verified cloud state

- `_wt/app-installers/qflistudio` is the old `ci/app-installers` checkout at `4f8d97d`, app version 5.0.1. Do not use it as the final product baseline.
- Public `qflistudio-next/main` and peeled `v5.0.4` both resolve to `b7272bc3a81482a9f84be08b2273d0b603ec9870`. Build the release worktree from this revision and integrate the reviewed migration there.
- Public core `main` is locally recorded at `cbaa4a4`. Verify its remote SHA again when preparing the final core integration. The migration's original core baseline is older, `b7f3d40`.
- GitHub run `44398723513` built tag `v5.0.4`. All 10 jobs succeeded. It produced 11 unexpired artifacts: Windows x64/arm64, Linux x64/arm64, macOS x86_64/arm64, Android x86_64/armeabi-v7a/arm64-v8a, iOS arm64, and OHOS arm64.
- Those artifacts expire on 2026-12-02 UTC. The repository currently has no GitHub Releases.
- Successful old artifacts do not verify the new migrated code.

API evidence, queried without authentication:

```text
GET https://api.github.com/repos/azurekiln2333/qflistudio-next/actions/runs/44398723513/jobs?per_page=100
GET https://api.github.com/repos/azurekiln2333/qflistudio-next/actions/runs/44398723513/artifacts?per_page=100
GET https://api.github.com/repos/azurekiln2333/qflistudio-next/releases?per_page=5
```

## Exact app and core revisions

`app-installers.yml` builds the app commit identified by the pushed tag. However, its six `app-setup` calls currently use `inputs.core_ref || 'main'`. A tag push has no `core_ref` input, so an unmodified workflow silently builds the core's moving main branch.

In the final app release commit, add `env.CORE_REF` containing the full reviewed and pushed core commit SHA. Replace all six expressions with:

```yaml
core-ref: ${{ inputs.core_ref || env.CORE_REF }}
```

The six locations in `b7272bc` are lines 163, 611, 804, 1006, 1134, and 1534. They cover Windows, Linux, macOS, iOS, Android, and OHOS.

The composite action checks out the supplied core ref. `tool/ci/stage_artifact.sh` records both `app_commit` and `core_commit` in every package's `BUILD_INFO.txt`. Require them to match the chosen SHA pair before publishing.

The upstream Flutter version is also currently moving: `inputs.flutter_version` defaults to the newest stable. For a reproducible preview, record a selected official version in the release workflow and use it as the fallback to that input. OHOS already pins its Flutter version and commit separately.

Suggested version semantics:

- App numeric version: `5.0.5+5000005` in `pubspec.yaml`.
- Workflow `APP_VERSION`: `5.0.5`.
- OHOS `AppScope/app.json5`: versionName `5.0.5`, versionCode `5000005`.
- Git preview tag: `v5.0.5-remote.1`; subsequent corrected candidate uses `.2`, without moving an existing tag.
- GitHub Release: prerelease, `latest=false`. Explain that package metadata is 5.0.5 and the Git tag identifies the preview candidate.

Keep the platform version strings numeric to avoid feeding a prerelease suffix into Apple/Windows package version fields. Do not mark this candidate as the stable latest release.

## Existing installer lines and risks

File: `.github/workflows/app-installers.yml` at `b7272bc`.

| Lines | Finding |
| --- | --- |
| 9-14 | Pushes to main, `ci/**`, and `v*` tags trigger builds. A `remote/**` branch push alone does not. |
| 44-53 | Manual dispatch supports `core_ref`, but tag pushes do not supply it. |
| 55-56 | Global token has `contents: read`. There is no release publishing job. |
| 77, 117-126 | Workflow APP_VERSION must equal the version read from pubspec.yaml. |
| 150 | Windows output is unsigned. Cloud CI does a silent installer check and inspects installed files. |
| 791 | macOS output uses an ad-hoc signature, without notarization. |
| 993 | iOS IPA is unsigned and cannot be installed directly. |
| 1121, 1166 | Android APKs use a newly generated debug key. They are installable, but cannot update a production-signed app. Fresh CI keys also prevent reliable upgrades between previews. |
| 1410, 1612 | OHOS HAP is unsigned. The workflow strips local signing configuration. It cannot be installed directly. |
| 556 and other upload steps | Artifacts are retained for 14 days. |

The latest app `tool/ci/patch_upstream_core.sh` only stubs the Huawei platform view, then rejects remaining `TargetPlatform.ohos`/`OhosView` references. The original migration baseline still contains these references in app main, editor, terminal, auth, interop, storage, and vendored re_editor files. Combining the latest installer with that old core without integration will fail this gate. Use the final integrated core that includes the existing compatibility work (`19d3798`, `a20a84c`, and the latest main descendants), or deliberately carry the reviewed compatibility fixes into the final branch.

Installer success alone is not test success. The existing installer workflow does not run the application test suites. Require the exact core/app/companion cloud test results before tagging, or include their verification jobs in the same workflow and add them to the publisher's `needs` list.

Do not push this preview tag to CNB. Its current `tag_push` also publishes server/terminal images, and the APK release path declares `latest: true`. The authorized release route for this task is GitHub only.

## Minimal GitHub preview publisher

Add this job to the final installer workflow. It assumes global `CORE_REF` is the pinned SHA and the six existing build job IDs remain unchanged. If tests are added as jobs in this workflow, include their IDs in `needs` too.

The download action's v8.0.2 tag was resolved via the official public GitHub API to commit `9000827ccba6bdab643e8b6fd33ac0654aef8333`. Keep that full pin.

```yaml
  publish-preview:
    name: Publish preview installers
    if: startsWith(github.ref, 'refs/tags/v') && contains(github.ref_name, '-remote.')
    needs: [windows, linux, macos, ios, android, ohos]
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    defaults:
      run:
        shell: bash
        working-directory: ${{ github.workspace }}
    steps:
      - name: Download this run's installer artifacts
        uses: actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2
        with:
          pattern: qflistudio-*
          path: packages
          merge-multiple: false

      - name: Check provenance and package release assets
        run: |
          python3 - <<'PY'
          from pathlib import Path
          import os
          reports = sorted(Path('packages').glob('*/BUILD_INFO.txt'))
          if len(reports) != 11:
              raise SystemExit(f'Expected 11 installer artifacts, got {len(reports)}')
          for path in reports:
              facts = dict(line.split('=', 1) for line in path.read_text().splitlines() if '=' in line)
              if facts.get('app_commit') != os.environ['GITHUB_SHA']:
                  raise SystemExit(f'Wrong app commit: {path}')
              if facts.get('core_commit') != os.environ['CORE_REF']:
                  raise SystemExit(f'Wrong core commit: {path}')
          PY
          mkdir -p release-assets
          for dir in packages/*; do
            test -d "$dir"
            (cd "$dir" && sha256sum --check SHA256SUMS)
            name="$(basename "$dir")"
            (cd "$dir" && zip -qr "$GITHUB_WORKSPACE/release-assets/$name.zip" .)
          done
          (cd release-assets && sha256sum ./*.zip > SHA256SUMS)

      - name: Publish a prerelease
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GH_REPO: ${{ github.repository }}
          RELEASE_TAG: ${{ github.ref_name }}
        run: |
          {
            printf 'App commit: %s\nCore commit: %s\n\n' "$GITHUB_SHA" "$CORE_REF"
            printf '%s\n' 'Cloud-built preview. No physical-device validation.'
            printf '%s\n' 'Android uses a debug certificate. Windows is unsigned. macOS is ad-hoc signed.'
            printf '%s\n' 'iOS and OHOS packages require signing before installation.'
          } > release-notes.md
          gh release create "$RELEASE_TAG" release-assets/* \
            --repo "$GH_REPO" --verify-tag --prerelease --latest=false \
            --title "QFLIStudioN $RELEASE_TAG" --notes-file release-notes.md
```

The job overrides the inherited `working-directory: qflistudio` because it does not check out the app. Each artifact remains in its own ZIP so identical BUILD_INFO.txt/LICENSE names cannot overwrite one another. A failed matrix target prevents the publish job. A retry after a partially created release requires explicit inspection; do not blindly clobber existing assets.

## Safe authentication and operational commands

The preferred publication credential is the job-scoped `GITHUB_TOKEN` above. This requires no local PAT, stored Git credential extraction, or new repository secret. Pass it through `GH_TOKEN` only. Do not enable shell tracing, print environment variables, or embed a token in a URL/command argument.

Read-only public status API requests need no token. Direct anonymous artifact download was tested with HEAD and returned HTTP 401. Users signed into GitHub can download Actions artifacts. A public prerelease provides durable public assets and avoids relying on the 14-day artifact window.

After the reviewed core and app commits exist, these are the intended publication commands. Placeholders must be replaced with the final worktrees and SHAs. Run them only from the coordinator, not from a Pi:

```powershell
git -C <release-core-worktree> push github HEAD:refs/heads/remote/cloudterminal-release
git -C <release-app-worktree> push github HEAD:refs/heads/ci/cloudterminal-preview
git -C <release-app-worktree> tag -a v5.0.5-remote.1 <final-app-sha> -m 'preview: remote computer integration'
git -C <release-app-worktree> push github refs/tags/v5.0.5-remote.1
```

The `ci/**` branch can validate the same committed SHA pair before the tag. Pinning CORE_REF means no main-branch push is required. Normal Git push uses the configured transport authentication without displaying it. If transport authentication fails, resolve that explicitly instead of reading credential stores. For local API operations, an already authenticated `gh` session may be used without `gh auth token`; otherwise prefer the tag-triggered workflow route.

Official references:

- https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts
- https://docs.github.com/en/actions/tutorials/authenticate-with-github_token
- https://cli.github.com/manual/gh_release_create
- https://github.com/actions/download-artifact/releases/tag/v8.0.2
