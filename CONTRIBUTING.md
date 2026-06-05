# Contributing to OpenMarked

Thanks for helping build OpenMarked.

The project is early, so the most useful contributions are focused, tested, and aligned with `MVP_IMPLEMENTATION_PLAN.md`.

## Build

```sh
swift build
swift run OpenMarkedVerifier
swift test
```

Open `Package.swift` in Xcode for app development.

Run the release gate before publishing an artifact:

```sh
Scripts/verify_release.sh
```

## Contribution Guidelines

- Keep MVP work scoped to the current phase unless a later-phase change is needed to unblock it.
- Prefer native macOS behavior over custom UI where the system control is appropriate.
- Keep renderer, preview, theme, file watching, and export code separated.
- Add or update fixtures when changing Markdown rendering behavior.
- Add tests for parsing, file handling, rendering, export, and state logic where practical.
- Keep user data local and private by default.
- Treat accessibility as part of the feature, not as cleanup.

## Code Style

- Use clear Swift names.
- Keep view code separate from document/rendering logic.
- Prefer small, testable services over large view models.
- Avoid force unwraps except in tests where the failure should be immediate.
- Add comments only when they clarify non-obvious behavior.

## Reporting Rendering Bugs

When reporting a rendering issue, include:

- The smallest Markdown example that reproduces the issue.
- Expected output.
- Actual output.
- macOS version.
- OpenMarked version or commit.
