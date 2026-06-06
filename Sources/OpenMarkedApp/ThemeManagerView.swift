import SwiftUI
import WebKit
import OpenMarkedCore

struct ThemeManagerView: View {
    @EnvironmentObject private var appController: AppController
    @Environment(\.appChromeTheme) private var chrome

    @State private var previewThemeID = PreviewThemeStore.defaultThemeID
    @State private var selectedBuiltInThemeID = PreviewThemeStore.defaultThemeID
    @State private var selectedUserThemeID = ""
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Picker("Preview", selection: $previewThemeID) {
                    ForEach(appController.availablePreviewThemes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .accessibilityLabel("Theme preview")

                Button {
                    appController.updateSettings { settings in
                        settings.defaultThemeID = previewThemeID
                    }
                    appController.setTheme(id: previewThemeID)
                } label: {
                    Label("Use Selected", systemImage: "checkmark.circle")
                }
                .disabled(appController.availablePreviewThemes.isEmpty)
            }

            ThemePreviewGallery(theme: appController.previewTheme(id: previewThemeID))
                .frame(height: 260)

            Divider()

            HStack(alignment: .top, spacing: 18) {
                builtInThemeControls
                    .frame(maxWidth: .infinity, alignment: .leading)

                userThemeControls
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            previewThemeID = appController.settings.defaultThemeID
            ensureUserThemeSelection()
        }
        .onChange(of: selectedUserThemeID) { _ in
            syncRenameText()
        }
        .onChange(of: appController.userPreviewThemes) { _ in
            ensureUserThemeSelection()
        }
        .onChange(of: appController.settings.defaultThemeID) { newThemeID in
            previewThemeID = newThemeID
        }
    }

    private var builtInThemeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Built-in Themes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(chrome.secondaryText)

            Picker("Built-in Theme", selection: $selectedBuiltInThemeID) {
                ForEach(PreviewThemeStore.allBuiltInThemes) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }

            HStack(spacing: 8) {
                Button {
                    previewThemeID = selectedBuiltInThemeID
                } label: {
                    Label("Preview", systemImage: "eye")
                }

                Button {
                    if let theme = appController.duplicateBuiltInPreviewTheme(id: selectedBuiltInThemeID) {
                        selectedUserThemeID = theme.id
                        renameText = theme.name
                        previewThemeID = theme.id
                    }
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private var userThemeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("User Themes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(chrome.secondaryText)

            Picker("User Theme", selection: $selectedUserThemeID) {
                if appController.userPreviewThemes.isEmpty {
                    Text("None").tag("")
                } else {
                    ForEach(appController.userPreviewThemes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
            }
            .disabled(appController.userPreviewThemes.isEmpty)

            TextField("Name", text: $renameText)
                .disabled(selectedUserTheme == nil)

            HStack(spacing: 8) {
                Button {
                    if let theme = appController.importPreviewTheme() {
                        selectedUserThemeID = theme.id
                        renameText = theme.name
                        previewThemeID = theme.id
                    }
                } label: {
                    Label("Import CSS", systemImage: "plus")
                }

                Button {
                    guard let themeID = selectedUserTheme?.id,
                          let theme = appController.renameUserPreviewTheme(id: themeID, name: renameText)
                    else {
                        return
                    }
                    selectedUserThemeID = theme.id
                    renameText = theme.name
                    previewThemeID = theme.id
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .disabled(selectedUserTheme == nil)

                Button(role: .destructive) {
                    guard let themeID = selectedUserTheme?.id else {
                        return
                    }
                    appController.deleteUserPreviewTheme(id: themeID)
                    previewThemeID = PreviewThemeStore.defaultThemeID
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedUserTheme == nil)

                Button {
                    appController.revealUserPreviewThemesFolder()
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
            }
        }
    }

    private var selectedUserTheme: UserPreviewTheme? {
        appController.userPreviewThemes.first { $0.id == selectedUserThemeID }
    }

    private func ensureUserThemeSelection() {
        if let selectedUserTheme {
            renameText = selectedUserTheme.name
            return
        }

        if let firstTheme = appController.userPreviewThemes.first {
            selectedUserThemeID = firstTheme.id
            renameText = firstTheme.name
        } else {
            selectedUserThemeID = ""
            renameText = ""
        }

        if !appController.availablePreviewThemes.contains(where: { $0.id == previewThemeID }) {
            previewThemeID = PreviewThemeStore.defaultThemeID
        }
    }

    private func syncRenameText() {
        renameText = selectedUserTheme?.name ?? ""
    }
}

private struct ThemePreviewGallery: View {
    @Environment(\.appChromeTheme) private var chrome

    let theme: PreviewTheme

    var body: some View {
        ThemePreviewWebView(theme: theme)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(chrome.separator, lineWidth: 1)
            )
            .accessibilityLabel("Theme preview gallery")
    }
}

private struct ThemePreviewWebView: NSViewRepresentable {
    let theme: PreviewTheme

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let signature = "\(theme.id)-\(theme.name)-\(theme.screenCSS.hashValue)-\(theme.codeHighlightingCSS.hashValue)"
        guard context.coordinator.loadedSignature != signature else {
            return
        }

        context.coordinator.loadedSignature = signature
        webView.loadHTMLString(Self.previewHTML(theme: theme), baseURL: nil)
    }

    final class Coordinator {
        var loadedSignature: String?
    }

    private static func previewHTML(theme: PreviewTheme) -> String {
        let state = RichMarkdownRenderState(
            documentFeatures: RichMarkdownDocumentFeatures(features: [.mermaid, .math, .gitHubCallouts])
        )
        return HTMLDocumentAssembler.assemble(
            title: "Theme Preview",
            bodyHTML: sampleBodyHTML,
            theme: theme,
            fontScale: 0.9,
            richMarkdownState: state
        )
    }

    private static let sampleBodyHTML = """
    <h1>Theme Preview</h1>
    <p>A fast look at prose rhythm, links, inline code, tables, task lists, callouts, diagrams, math, and print styling.</p>
    <blockquote>
    <p>Markdown should feel readable before it feels decorative.</p>
    </blockquote>
    <ul>
    <li><input type="checkbox" checked disabled> Render GitHub-flavored Markdown</li>
    <li><input type="checkbox" disabled> Polish export-ready documents</li>
    </ul>
    <table>
    <thead><tr><th>Area</th><th>Status</th></tr></thead>
    <tbody><tr><td>Tables</td><td>Readable</td></tr><tr><td>Code</td><td>Offline</td></tr></tbody>
    </table>
    <pre class="om-code-block"><code><span class="om-code-keyword">let</span> theme = <span class="om-code-string">"Custom CSS"</span>
    preview.render(theme)</code></pre>
    <aside class="om-callout om-callout-note" data-callout="note">
      <p class="om-callout-title">Note</p>
      <div class="om-callout-body"><p>User themes use local CSS files and safe fallbacks.</p></div>
    </aside>
    <div class="om-rich-content om-mermaid-container" data-openmarked-rich-content="mermaid">
      <div class="om-rich-content-label">Mermaid</div>
      <pre>flowchart LR
      Markdown --> Preview
      Preview --> Export</pre>
    </div>
    <p>Inline math sample: <span class="katex">E = mc<sup>2</sup></span>. Display math and print CSS share the same theme.</p>
    <hr>
    <p><strong>Print:</strong> margins, code blocks, and tables should remain calm on paper.</p>
    """
}
