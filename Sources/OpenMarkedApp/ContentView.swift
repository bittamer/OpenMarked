import SwiftUI
import OpenMarkedCore

struct ContentView: View {
    @EnvironmentObject private var appController: AppController
    @StateObject private var controller: DocumentWindowController
    @State private var isDropTargeted = false

    init(controller: DocumentWindowController = DocumentWindowController()) {
        _controller = StateObject(wrappedValue: controller)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppToolbar(controller: controller)

            Divider()

            HStack(spacing: 0) {
                if controller.state.layout.isOutlineVisible {
                    OutlineSidebar(controller: controller)
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

                    Divider()
                }

                PreviewShell(controller: controller, isDropTargeted: isDropTargeted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            StatusBar(controller: controller)
        }
        .background(
            WindowAccessor { window in
                controller.window = window
                appController.registerWindowController(controller)
            }
        )
        .onAppear {
            appController.registerWindowController(controller)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow, window === controller.window else {
                return
            }
            appController.setActiveWindowController(controller)
        }
        .onChange(of: controller.state.windowTitle) { _ in
            controller.updateWindowTitle()
        }
        .onDisappear {
            controller.persistCurrentWindowState()
        }
        .dropDestination(for: URL.self) { urls, _ in
            appController.openDroppedURLs(urls, into: controller)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }
}

private struct AppToolbar: View {
    @EnvironmentObject private var appController: AppController
    @ObservedObject var controller: DocumentWindowController

    var body: some View {
        HStack(spacing: 10) {
            Button {
                appController.presentOpenPanel()
            } label: {
                Label("Open", systemImage: "folder")
            }
            .labelStyle(.iconOnly)
            .help("Open a Markdown file")
            .accessibilityLabel("Open Markdown file")

            Button {
                controller.reloadPreviewPlaceholder()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .help("Reload preview")
            .accessibilityLabel("Reload preview")
            .disabled(!controller.state.canReloadPreview)

            Button {
                controller.toggleOutline()
            } label: {
                Label("Toggle Outline", systemImage: "sidebar.left")
            }
            .labelStyle(.iconOnly)
            .help("Toggle outline")
            .accessibilityLabel("Toggle outline")

            Spacer()

            Picker("Theme", selection: themeBinding) {
                Text("Default").tag("default")
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .help("Preview theme")

            Button {
                controller.searchPlaceholder()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .help("Search document")
            .accessibilityLabel("Search document")
            .disabled(!controller.state.hasDocument)

            Button {
                controller.exportHTMLPlaceholder()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .help("Export document")
            .accessibilityLabel("Export document")
            .disabled(!controller.state.canExport)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var themeBinding: Binding<String> {
        Binding(
            get: { controller.state.layout.selectedThemeID },
            set: { controller.setTheme(id: $0) }
        )
    }
}

private struct OutlineSidebar: View {
    @ObservedObject var controller: DocumentWindowController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Outline", systemImage: "list.bullet.indent")
                .font(.headline)
                .foregroundStyle(.secondary)

            switch controller.state.content {
            case .loaded:
                Text("Headings will appear here once Markdown rendering lands.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .loading:
                ProgressView()
                    .controlSize(.small)
            case .error:
                Text("Open a valid Markdown file to build an outline.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .empty:
                Text("Open a Markdown document to build an outline.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
    }
}

private struct PreviewShell: View {
    @EnvironmentObject private var appController: AppController
    @ObservedObject var controller: DocumentWindowController
    let isDropTargeted: Bool

    var body: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .padding(18)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        switch controller.state.content {
        case .empty:
            EmptyDocumentView {
                appController.presentOpenPanel()
            }
        case .loading(let pending):
            VStack(spacing: 14) {
                ProgressView()
                Text("Opening \(pending.displayName)")
                    .foregroundStyle(.secondary)
            }
        case .loaded(let document):
            LoadedDocumentPlaceholder(document: document)
        case .error(let error):
            ErrorDocumentView(error: error) {
                appController.presentOpenPanel()
            }
        }
    }
}

private struct EmptyDocumentView: View {
    let openAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(AppInfo.name)
                    .font(.largeTitle.weight(.semibold))

                Text(AppInfo.summary)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Button(action: openAction) {
                Label("Open Markdown File", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding()
    }
}

private struct LoadedDocumentPlaceholder: View {
    let document: OpenedDocument

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(document.displayName)
                    .font(.title.weight(.semibold))
                Text("Markdown rendering lands in Phase 3.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(document.url.path, systemImage: "location")
                    .lineLimit(2)
                Label(document.fileExtension.uppercased(), systemImage: "doc")
                if let statistics = document.markdownDocument?.statistics {
                    Label("\(statistics.wordCount) words, \(statistics.lineCount) lines", systemImage: "text.word.spacing")
                }
                if let title = document.markdownDocument?.frontMatter?.title {
                    Label("Title: \(title)", systemImage: "tag")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(32)
    }
}

private struct ErrorDocumentView: View {
    let error: DocumentOpenError
    let openAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Could Not Open Document")
                    .font(.title.weight(.semibold))

                Text(error.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            Button(action: openAction) {
                Label("Choose Another File", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(32)
    }
}

private struct StatusBar: View {
    @ObservedObject var controller: DocumentWindowController

    var body: some View {
        HStack(spacing: 16) {
            Label(statusTitle, systemImage: statusIcon)
                .foregroundStyle(.secondary)

            Text(controller.state.statusMessage)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if let statistics = controller.state.currentMarkdownDocument?.statistics {
                Text("\(statistics.wordCount) words")
                Text("\(statistics.readingTimeMinutes) min read")
            }
            Text("Zoom \(Int((controller.state.layout.fontScale * 100).rounded()))%")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var statusTitle: String {
        switch controller.state.content {
        case .empty:
            return "No Document"
        case .loading:
            return "Opening"
        case .loaded(let document):
            return document.displayName
        case .error:
            return "Error"
        }
    }

    private var statusIcon: String {
        switch controller.state.content {
        case .empty:
            return "circle"
        case .loading:
            return "clock"
        case .loaded:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.circle"
        }
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Section("MVP Defaults") {
                Picker("Default Theme", selection: .constant("Default")) {
                    Text("Default").tag("Default")
                }

                Toggle("Live updates", isOn: .constant(true))
                Toggle("Preserve scroll position", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
    }
}
