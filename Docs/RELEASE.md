# OpenMarked 0.4.1 Release Gate

This document captures the current release process. Do not tag a release until `Scripts/verify_release.sh` passes, the checklist in `Docs/QA.md` has been run by a person, and the project owner has approved the release.

## Automated Commands

```sh
Scripts/verify_release.sh
```

The command builds debug and release products, runs the verifier, runs the performance smoke test, captures and verifies visual snapshots, verifies PDF/export artifacts, runs SwiftPM tests, checks package metadata, checks diff whitespace, scans for accidental non-ASCII text outside generated output, builds `OpenMarked.app`, verifies packaged rich-content resources are present, signs it, verifies the signature, and creates ZIP and DMG artifacts.

## Artifact

The local developer artifact is:

```text
dist/OpenMarked-0.4.1-macOS.zip
dist/OpenMarked-0.4.1-macOS.dmg
```

The app bundle is ad hoc signed by default for local developer distribution. Set `OPENMARKED_SIGN_IDENTITY` to use a Developer ID identity. Set `OPENMARKED_NOTARIZE=1` with Apple notarization credentials to submit and staple the DMG. Without notarization, Gatekeeper may require users to open through Finder's context menu or remove quarantine after they understand the risk.

## Final Manual Gate

- Automated release gate: passed on 2026-06-08 with `Scripts/verify_release.sh`
- QA runner: Codex on macOS 26.5.1
- Artifact path: `dist/OpenMarked-0.4.1/OpenMarked.app`, `dist/OpenMarked-0.4.1-macOS.zip`, and `dist/OpenMarked-0.4.1-macOS.dmg`
- QA checklist: `Docs/QA.md`
- Fixture visual QA: screenshot baseline and manifest coverage recorded in `Docs/VISUAL_QA.md`
- PDF/export artifact QA: automated through `Scripts/verify_export_artifacts.sh`, including preview, palette, inspector, settings, and rich Markdown PDFs
- Print panel QA: owner-recorded manual pass recommended before public distribution
- Second Mac or clean-account launch: owner-recorded manual pass recommended before public distribution
- Owner approval: accepted through the Phase 8 release request
- Release tag: `0.4.1`

Use this command only after approval and after all release changes are committed:

```sh
git tag -a 0.4.1 -m "OpenMarked 0.4.1"
```

## P1 Deferrals

- Developer ID signing and notarized public distribution require Apple credentials.
- Homebrew Cask is deferred until release artifacts are published from a stable URL.
- Strict visual hash comparison is optional through `OPENMARKED_STRICT_VISUAL_HASHES=1`; normal verification checks snapshot presence, dimensions, cases, surface metadata, and nonblank image sizes to avoid OS-font rendering flakes.
- Folder workspaces, backlinks, export profiles, DOCX/EPUB export, plugin processors, and automation hooks remain future releases.
