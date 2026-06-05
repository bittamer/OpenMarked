# OpenMarked 0.1.0 Release Gate

This document captures the MVP release process. Do not tag `0.1.0` until the checklist in `Docs/QA.md` has been run by a person and the project owner has approved the release.

## Automated Commands

```sh
Scripts/verify_release.sh
```

The command builds debug and release products, runs the verifier, runs the performance smoke test, runs SwiftPM tests, checks package metadata, checks diff whitespace, scans for accidental non-ASCII text outside generated output, builds `OpenMarked.app`, ad hoc signs it, verifies the signature, and creates a ZIP.

## Artifact

The local developer artifact is:

```text
dist/OpenMarked-0.1.0-macOS.zip
```

The app bundle inside the ZIP is ad hoc signed for local developer distribution. It is not notarized. Gatekeeper may require users to open it through Finder's context menu or remove quarantine after they understand the risk.

## Final Manual Gate

- QA checklist: not yet owner-recorded
- Fixture visual QA: not yet owner-recorded
- PDF/print visual QA: not yet owner-recorded
- Second Mac or clean-account launch: not yet owner-recorded
- Owner approval: pending
- Release tag: pending

Use this command only after approval and after all release changes are committed:

```sh
git tag -a 0.1.0 -m "OpenMarked 0.1.0"
```

## P1 Deferrals

- Signed/notarized public distribution is deferred until signing credentials are available.
- DMG creation and Homebrew Cask are deferred until after the first ZIP artifact is validated.
- Full automated visual regression testing is deferred; Phase 10 uses manual visual QA plus renderer/export smoke coverage.
