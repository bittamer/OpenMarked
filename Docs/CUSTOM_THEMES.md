# OpenMarked Custom Themes

OpenMarked 0.4.0 includes a native Theme Manager for built-in preview themes and user-imported CSS themes. Themes affect the rendered Markdown preview and export styling; they do not add processors, scripts, or plugins.

## Built-In Themes

OpenMarked ships these preview themes:

- Default.
- GitHub.
- Minimal.
- Catppuccin.
- Tokyo Night.
- Everforest.
- Nord.
- Rose Pine.
- Dracula.
- Gruvbox.

Each built-in theme has screen CSS, print CSS, and code highlighting CSS. Themes support light and dark appearance where practical.

## Theme Manager

Open Settings and use Theme Manager to:

- Preview any available theme in a built-in gallery.
- Apply the selected theme as the active/default preview theme.
- Import a local CSS file as a user theme.
- Duplicate a built-in theme into editable user CSS files.
- Rename a user theme.
- Delete a user theme.
- Reveal the managed theme folder in Finder.

The preview gallery includes prose, links, inline code, code blocks, tables, task lists, callouts, rich-content placeholders, and print-style coverage.

## Storage

Imported and duplicated user themes are copied into:

```text
~/Library/Application Support/OpenMarked/Themes
```

OpenMarked stores only metadata in `UserDefaults`; the CSS lives in the managed themes directory. Deleting a user theme removes only files that OpenMarked manages inside that directory.

## CSS Safety Rules

Custom themes are CSS-only and local-only.

OpenMarked blocks:

- Non-local theme files.
- Files that are not `.css`.
- Empty CSS.
- CSS `@import` rules.
- `javascript:` URLs.
- Embedded `<script>` tags.
- Embedded `<style>` tags.

If a user theme file later becomes unreadable or unsafe, OpenMarked falls back to the Default theme CSS for that missing piece instead of rendering unsafe content.

## What Custom Themes Can Do

Custom CSS can style the generated preview HTML, including typography, colors, spacing, tables, code blocks, blockquotes, GitHub callouts, Mermaid containers, KaTeX output, and print styles when the theme has print CSS.

Duplicating a built-in theme creates separate screen, code, and print CSS files. Importing a CSS file creates a screen theme and uses Default code/print CSS fallback unless those files are later supplied by a duplicated theme.

## What Custom Themes Cannot Do

Custom themes cannot:

- Execute JavaScript.
- Load remote CSS through `@import`.
- Install Markdown processors.
- Change cmark-gfm parsing.
- Fetch remote assets by themselves.
- Override OpenMarked privacy settings.

For processor plugins, export profiles, or richer publishing workflows, use the roadmap rather than themes.
