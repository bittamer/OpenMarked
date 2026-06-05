# Diagnostics And Logs

OpenMarked is local-first and does not upload crash reports, logs, document contents, or usage data.

When reporting a bug, share only the smallest information needed to reproduce the problem.

## Useful Environment Details

- OpenMarked version and build.
- macOS version.
- Mac model or chip.
- Whether the app was launched from SwiftPM, Xcode, ZIP, or DMG.
- Whether the issue happens with a public fixture in `Fixtures/Markdown`.

## Crash Reports

If OpenMarked crashes, macOS may write a crash report under:

```text
~/Library/Logs/DiagnosticReports/
```

Look for files whose names start with `OpenMarked`. Before attaching a report:

- Remove user names from paths if needed.
- Remove private file names or document text.
- Keep stack traces and exception details when possible.

## Console Logs

To inspect recent logs locally:

```sh
log show --predicate 'process == "OpenMarked"' --last 10m
```

Before sharing logs:

- Remove private paths.
- Remove source document contents.
- Remove tokens, credentials, or URLs that should not be public.

## Rendering Bugs

Rendering issues are easiest to fix with:

- A minimal Markdown sample.
- Any local image or linked fixture needed to reproduce the output.
- The selected theme and font scale.
- Whether the issue appears in preview, HTML export, PDF export, or print.
