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
            controller.close()
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
                controller.reloadPreview()
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
                ForEach(PreviewThemeStore.allBuiltInThemes) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .help("Preview theme")
            .accessibilityLabel("Preview theme")

            Button {
                controller.showSearch()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .help("Search document")
            .accessibilityLabel("Search document")
            .disabled(!controller.state.hasDocument)

            Menu {
                Button("Reveal in Finder") {
                    controller.revealSourceInFinder()
                }
                Button("Open in Default Editor") {
                    controller.openSourceInDefaultEditor()
                }
                Button("Copy File Path") {
                    controller.copySourcePath()
                }
                Divider()
                Button("Reload from Disk") {
                    controller.reloadPreview()
                }
            } label: {
                Label("Source", systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .help("Source file actions")
            .accessibilityLabel("Source file actions")
            .disabled(!controller.state.hasDocument)

            Menu {
                Button("Export HTML...") {
                    controller.exportHTML()
                }
                Button("Export PDF...") {
                    controller.exportPDF()
                }
                Button("Copy Rendered HTML") {
                    controller.copyRenderedHTML()
                }
                Divider()
                Button("Print...") {
                    controller.printDocument()
                }
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
    @State private var outlineFilter = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Outline", systemImage: "list.bullet.indent")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("Filter headings", text: $outlineFilter)
                .textFieldStyle(.roundedBorder)

            switch controller.state.content {
            case .loaded:
                if let outline = controller.state.currentRenderResult?.outline, !outline.isEmpty {
                    let filteredOutline = OutlineFilter.filter(outline, query: outlineFilter)
                    if filteredOutline.isEmpty {
                        Text("No matching headings.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(filteredOutline) { item in
                                    Button {
                                        controller.scrollToOutlineItem(item)
                                    } label: {
                                        Text(item.title)
                                            .font(.callout)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, outlineLeadingPadding(for: item))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 3)
                                    .help("Jump to \(item.title)")
                                }
                            }
                        }
                    }
                } else {
                    Text("This document has no headings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
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

    private func outlineLeadingPadding(for item: OutlineItem) -> CGFloat {
        if outlineFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CGFloat(max(0, item.level - 1)) * 12
        }
        return 0
    }
}

private struct PreviewShell: View {
    @EnvironmentObject private var appController: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            switch controller.state.preview {
            case .loading:
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Rendering \(document.displayName)")
                        .foregroundStyle(.secondary)
                }
            case .rendered(let result):
                VStack(spacing: 0) {
                    if controller.state.search.isVisible {
                        FindBar(controller: controller)
                        Divider()
                    }

                    PreviewWebView(
                        renderResult: result,
                        baseURL: document.url.deletingLastPathComponent(),
                        navigationRequest: controller.previewNavigationRequest,
                        searchRequest: controller.previewSearchRequest,
                        preservesScrollPosition: appController.settings.preservesScrollPosition,
                        usesReducedMotion: reduceMotion,
                        onStatusUpdate: { message in
                            controller.updatePreviewStatus(message)
                        },
                        onSearchResult: { result in
                            controller.updateSearchResult(result)
                        }
                    )
                }
            case .error(let error):
                PreviewErrorView(error: error)
            case .idle, .placeholder:
                LoadedDocumentPlaceholder(document: document)
            }
        case .error(let error):
            ErrorDocumentView(error: error) {
                appController.presentOpenPanel()
            }
        }
    }
}

private struct FindBar: View {
    @ObservedObject var controller: DocumentWindowController
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find in preview", text: searchQueryBinding)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    controller.findNext()
                }

            Text(controller.state.search.resultSummary)
                .foregroundStyle(.secondary)
                .frame(minWidth: 76, alignment: .trailing)

            Button {
                controller.findPrevious()
            } label: {
                Label("Previous", systemImage: "chevron.up")
            }
            .labelStyle(.iconOnly)
            .help("Previous match")
            .disabled(controller.state.search.query.isEmpty)

            Button {
                controller.findNext()
            } label: {
                Label("Next", systemImage: "chevron.down")
            }
            .labelStyle(.iconOnly)
            .help("Next match")
            .disabled(controller.state.search.query.isEmpty)

            Button {
                controller.hideSearch()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .help("Close search")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .onAppear {
            isFocused = true
        }
        .onExitCommand {
            controller.hideSearch()
        }
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { controller.state.search.query },
            set: { controller.updateSearchQuery($0) }
        )
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Empty document")
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
                Text("Preview is ready.")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loaded document summary")
    }
}

private struct PreviewErrorView: View {
    let error: PreviewError

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Could Not Render Preview")
                    .font(.title.weight(.semibold))

                Text(error.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
        }
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview render error")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Document open error")
    }
}

private struct StatusBar: View {
    @ObservedObject var controller: DocumentWindowController
    @State private var isDiagnosticsPopoverPresented = false

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
                    .help("\(statistics.characterCount) characters, \(statistics.lineCount) lines")
                Text("\(statistics.readingTimeMinutes) min read")
                    .help("\(statistics.characterCount) characters, \(statistics.lineCount) lines")
            }
            if let diagnostics = controller.state.currentRenderResult?.diagnostics, !diagnostics.isEmpty {
                Button {
                    isDiagnosticsPopoverPresented.toggle()
                } label: {
                    Label("\(diagnostics.count) warning\(diagnostics.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isDiagnosticsPopoverPresented, arrowEdge: .bottom) {
                    DiagnosticsPopover(diagnostics: diagnostics)
                }
            }
            if let livePreviewStatusTitle {
                Label(livePreviewStatusTitle, systemImage: livePreviewStatusIcon)
                    .labelStyle(.titleAndIcon)
            }
            Text(PreviewThemeStore.theme(id: controller.state.layout.selectedThemeID).name)
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

    private var livePreviewStatusTitle: String? {
        switch controller.state.livePreview {
        case .inactive:
            return nil
        case .watching:
            return "Watching"
        case .updating:
            return "Updating"
        case .updated:
            return "Updated just now"
        case .failed:
            return "Update failed"
        }
    }

    private var livePreviewStatusIcon: String {
        switch controller.state.livePreview {
        case .inactive, .watching:
            return "eye"
        case .updating:
            return "arrow.triangle.2.circlepath"
        case .updated:
            return "bolt"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

private struct DiagnosticsPopover: View {
    let diagnostics: [RenderDiagnostic]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics")
                .font(.headline)

            if diagnostics.isEmpty {
                Text("No warnings.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(diagnostics) { diagnostic in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(diagnostic.severity.rawValue.capitalized, systemImage: icon(for: diagnostic))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(color(for: diagnostic))
                                Text(diagnostic.message)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let source = diagnostic.source {
                                    Text(source)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(14)
        .frame(width: 360)
    }

    private func icon(for diagnostic: RenderDiagnostic) -> String {
        switch diagnostic.severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }

    private func color(for diagnostic: RenderDiagnostic) -> Color {
        switch diagnostic.severity {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appController: AppController

    var body: some View {
        Form {
            Section("Preview Defaults") {
                Picker("Default Theme", selection: settingBinding(\.defaultThemeID)) {
                    ForEach(PreviewThemeStore.allBuiltInThemes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .accessibilityLabel("Default preview theme")

                HStack {
                    Slider(value: fontScaleBinding, in: 0.6...2.0, step: 0.05) {
                        Text("Default Font Scale")
                    }
                    Text("\(Int((appController.settings.defaultFontScale * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }

                Toggle("Live updates", isOn: settingBinding(\.isLivePreviewEnabled))
                Toggle("Preserve scroll position", isOn: settingBinding(\.preservesScrollPosition))
                Toggle("Restore last opened documents", isOn: settingBinding(\.restoresLastOpenedDocuments))
            }

            Section("Content") {
                Toggle("Load remote images", isOn: settingBinding(\.allowsRemoteImages))
                Toggle("Allow raw HTML", isOn: settingBinding(\.allowsRawHTML))
            }

            Section("Export") {
                Toggle("Embed CSS in HTML export", isOn: settingBinding(\.embedsCSSInHTMLExport))
                Toggle("Embed local images in HTML export", isOn: settingBinding(\.embedsLocalImagesInHTMLExport))
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
        .accessibilityLabel("OpenMarked settings")
    }

    private func settingBinding<Value>(_ keyPath: WritableKeyPath<ApplicationSettings, Value>) -> Binding<Value> {
        Binding(
            get: { appController.settings[keyPath: keyPath] },
            set: { newValue in
                appController.updateSettings { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var fontScaleBinding: Binding<Double> {
        Binding(
            get: { appController.settings.defaultFontScale },
            set: { newValue in
                appController.updateSettings { settings in
                    settings.defaultFontScale = newValue
                }
            }
        )
    }
}
