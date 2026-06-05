# Link Validation

OpenMarked 0.3.0 validates links during local rendering without contacting remote servers by default.

## What Is Checked

- Same-document heading fragments such as `#getting-started`.
- Document-relative files such as `guide.md` and `../assets/logo.png`.
- Absolute `file://` links.
- Heading fragments in linked Markdown files when the target file is local, readable, and small enough to inspect.
- Malformed remote links such as `https://`.
- Unsupported schemes such as `javascript:`.

Existing local image diagnostics remain separate from link diagnostics. A missing image used as an image produces an image diagnostic; the same missing file used as a normal link produces a link diagnostic.

## What Is Not Checked Automatically

OpenMarked does not crawl `http` or `https` links during normal preview rendering. This keeps document previews fast, private, deterministic, and offline-friendly.

When remote validation is enabled internally, OpenMarked reports that the remote link was parsed but not checked automatically. A future manual remote checker should be explicit and cancellable.

## Cross-Document Heading Checks

For links like `guide.md#setup`, OpenMarked validates the target heading only when:

- the target file exists locally;
- the target file has a supported Markdown/text extension;
- the file can be read; and
- the file is at or below the validator size limit.

If the target file is too large or cannot be inspected, OpenMarked shows an informational skipped-check diagnostic instead of blocking rendering.

## Future Remote Checker Design

A future "Check Remote Links" action should:

- run only after explicit user action or an opt-in setting;
- explain that external servers will be contacted;
- use short timeouts;
- support cancellation;
- limit concurrent requests;
- avoid sending document contents;
- cache recent results briefly;
- handle redirects conservatively;
- identify OpenMarked with a clear user agent; and
- never run as part of ordinary live preview reloads.

