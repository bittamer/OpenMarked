# OpenMarked 0.5.1 Release Gate

This document captures the current release process. Do not tag a release until `Scripts/verify_release.sh` passes, the checklist in `Docs/QA.md` has been run by a person, and the project owner has approved the release.

## Automated Commands

```sh
Scripts/verify_release.sh
Scripts/performance_scroll_audit.sh
```

The release verification command builds debug and release products, runs the verifier, runs the performance smoke test, captures and verifies visual snapshots, verifies PDF/export artifacts, runs SwiftPM tests, checks package metadata, checks diff whitespace, scans for accidental non-ASCII text outside generated output, builds `OpenMarked.app`, verifies packaged rich-content resources are present, signs it, verifies the signature, and creates ZIP and DMG artifacts. The performance scroll audit opens the packaged app against the generated large-image fixture and records scroll-time and post-settle CPU/RSS plus stack samples.

## Artifact

The local developer artifact is:

```text
dist/OpenMarked-0.5.1-macOS.zip
dist/OpenMarked-0.5.1-macOS.dmg
```

The app bundle is ad hoc signed by default for local developer distribution. Set `OPENMARKED_SIGN_IDENTITY` to use a Developer ID identity. Set `OPENMARKED_NOTARIZE=1` with Apple notarization credentials to submit and staple the DMG. Without notarization, Gatekeeper may require users to open through Finder's context menu or remove quarantine after they understand the risk.

## Final Manual Gate

- Automated release gate: passed on 2026-06-09 with `Scripts/verify_release.sh`
- Performance scroll audit: passed on 2026-06-09 with `Scripts/performance_scroll_audit.sh`
- QA runner: Codex on macOS 26.5.1
- Artifact path: `dist/OpenMarked-0.5.1/OpenMarked.app`, `dist/OpenMarked-0.5.1-macOS.zip`, and `dist/OpenMarked-0.5.1-macOS.dmg`
- Performance audit report: `.build/perf-audit/performance-scroll-report.md`
- Final performance audit result: post-settle CPU `0.0%`, post-settle RSS about `171 MB`, and zero hot-stack matches for repeated status statistics or theme CSS loading.
- QA checklist: `Docs/QA.md`
- Fixture visual QA: screenshot baseline and manifest coverage recorded in `Docs/VISUAL_QA.md`
- PDF/export artifact QA: automated through `Scripts/verify_export_artifacts.sh`, including preview, palette, inspector, settings, and rich Markdown PDFs
- Print panel QA: owner-recorded manual pass recommended before public distribution
- Second Mac or clean-account launch: owner-recorded manual pass recommended before public distribution
- Owner approval: approved for `v0.5.1` tag creation on 2026-06-09; GitHub publication remains owner-controlled.
- Release tag: `v0.5.1`

Use this command only after approval and after all release changes are committed:

```sh
git tag -a v0.5.1 -m "OpenMarked 0.5.1"
```

## P1 Deferrals

- Developer ID signing and notarized public distribution require Apple credentials.
- Homebrew Cask is deferred until release artifacts are published from a stable URL.
- Strict visual hash comparison is optional through `OPENMARKED_STRICT_VISUAL_HASHES=1`; normal verification checks snapshot presence, dimensions, cases, surface metadata, and nonblank image sizes to avoid OS-font rendering flakes.
- Exact native tab order, previous tab group topology, and duplicate-document focusing remain future tabbing work.
- DOM diffing for render-changing live preview edits remains future performance work.
- Folder workspaces, backlinks, export profiles, DOCX/EPUB export, plugin processors, and automation hooks remain future releases.
