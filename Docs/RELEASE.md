# OpenMarked 0.2.0 Release Gate

This document captures the current release process. Do not tag a release until `Scripts/verify_release.sh` passes, the checklist in `Docs/QA.md` has been run by a person, and the project owner has approved the release.

## Automated Commands

```sh
Scripts/verify_release.sh
```

The command builds debug and release products, runs the verifier, runs the performance smoke test, captures and verifies visual snapshots, verifies PDF/export artifacts, runs SwiftPM tests, checks package metadata, checks diff whitespace, scans for accidental non-ASCII text outside generated output, builds `OpenMarked.app`, verifies packaged rich-content resources, signs it, verifies the signature, and creates ZIP and DMG artifacts.

## Artifact

The local developer artifact is:

```text
dist/OpenMarked-0.2.0-macOS.zip
dist/OpenMarked-0.2.0-macOS.dmg
```

The app bundle is ad hoc signed by default for local developer distribution. Set `OPENMARKED_SIGN_IDENTITY` to use a Developer ID identity. Set `OPENMARKED_NOTARIZE=1` with Apple notarization credentials to submit and staple the DMG. Without notarization, Gatekeeper may require users to open through Finder's context menu or remove quarantine after they understand the risk.

## Final Manual Gate

- QA checklist: partially recorded in `Docs/VISUAL_QA.md`
- Fixture visual QA: screenshot baseline and Computer Use pass recorded in `Docs/VISUAL_QA.md`
- PDF/export artifact QA: automated through `Scripts/verify_export_artifacts.sh`, including rich Markdown light/dark PDFs
- Print panel QA: not yet owner-recorded
- Second Mac or clean-account launch: not yet owner-recorded
- Owner approval: pending
- Release tag: pending

Use this command only after approval and after all release changes are committed:

```sh
git tag -a 0.2.0 -m "OpenMarked 0.2.0"
```

## P1 Deferrals

- Developer ID signing and notarized public distribution require Apple credentials.
- Homebrew Cask is deferred until release artifacts are published from a stable URL.
- Strict visual hash comparison is optional through `OPENMARKED_STRICT_VISUAL_HASHES=1`; normal verification checks snapshot presence, dimensions, cases, and nonblank image sizes to avoid OS-font rendering flakes.
