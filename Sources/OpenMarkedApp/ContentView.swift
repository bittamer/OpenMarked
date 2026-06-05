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

            ChromeDivider()

            HStack(spacing: 0) {
                if controller.state.layout.isOutlineVisible {
                    OutlineSidebar(controller: controller)
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

                    ChromeDivider(.vertical)
                }

                PreviewShell(controller: controller, isDropTargeted: isDropTargeted)

                if controller.state.layout.isInspectorVisible {
                    ChromeDivider(.vertical)

                    InspectorSidebar(controller: controller)
                        .frame(minWidth: 240, idealWidth: 286, maxWidth: 340)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ChromeDivider()

            StatusBar(controller: controller)
        }
        .appChromeTheme(appController.settings.appChromeThemeID)
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
    @Environment(\.appChromeTheme) private var chrome
    @ObservedObject var controller: DocumentWindowController

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ToolbarIconButton(
                    systemImage: "folder",
                    help: "Open a Markdown file",
                    accessibilityLabel: "Open Markdown file"
                ) {
                    appController.presentOpenPanel()
                }

                ToolbarIconButton(
                    systemImage: "arrow.clockwise",
                    help: "Reload preview",
                    accessibilityLabel: "Reload preview",
                    isDisabled: !controller.state.canReloadPreview
                ) {
                    controller.reloadPreview()
                }

                ToolbarIconButton(
                    systemImage: "sidebar.left",
                    help: "Toggle outline",
                    accessibilityLabel: "Toggle outline",
                    isActive: controller.state.layout.isOutlineVisible
                ) {
                    controller.toggleOutline()
                }

                ToolbarIconButton(
                    systemImage: "sidebar.right",
                    help: "Toggle inspector",
                    accessibilityLabel: "Toggle inspector",
                    isActive: controller.state.layout.isInspectorVisible
                ) {
                    controller.toggleInspector()
                }
            }

            Spacer(minLength: 12)

            ZoomControl(controller: controller)

            ToolbarSeparator()

            Picker("Theme", selection: themeBinding) {
                ForEach(PreviewThemeStore.allBuiltInThemes) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 132)
            .help("Preview theme")
            .accessibilityLabel("Preview theme")

            ToolbarSeparator()

            HStack(spacing: 2) {
                ToolbarIconButton(
                    systemImage: "magnifyingglass",
                    help: "Search document",
                    accessibilityLabel: "Search document",
                    isDisabled: !controller.state.hasDocument
                ) {
                    controller.showSearch()
                }

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
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
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
                    Image(systemName: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Export document")
                .accessibilityLabel("Export document")
                .disabled(!controller.state.canExport)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(chrome.toolbarBackground)
    }

    private var themeBinding: Binding<String> {
        Binding(
            get: { controller.state.layout.selectedThemeID },
            set: { controller.setTheme(id: $0) }
        )
    }
}

private struct ToolbarIconButton: View {
    @Environment(\.appChromeTheme) private var chrome

    let systemImage: String
    let help: String
    let accessibilityLabel: String
    var isActive: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
                .foregroundStyle(isActive ? chrome.accent : chrome.text)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundFill)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundFill: Color {
        if isActive {
            return chrome.accent.opacity(0.16)
        }
        if isHovering && !isDisabled {
            return chrome.text.opacity(0.08)
        }
        return .clear
    }
}

private enum ChromeDividerOrientation {
    case horizontal
    case vertical
}

private struct ChromeDivider: View {
    @Environment(\.appChromeTheme) private var chrome

    let orientation: ChromeDividerOrientation

    init(_ orientation: ChromeDividerOrientation = .horizontal) {
        self.orientation = orientation
    }

    var body: some View {
        Rectangle()
            .fill(chrome.separator)
            .frame(
                width: orientation == .vertical ? 1 : nil,
                height: orientation == .horizontal ? 1 : nil
            )
    }
}

private struct ToolbarSeparator: View {
    @Environment(\.appChromeTheme) private var chrome

    var body: some View {
        Rectangle()
            .fill(chrome.separator)
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }
}

private struct ZoomControl: View {
    @Environment(\.appChromeTheme) private var chrome
    @ObservedObject var controller: DocumentWindowController

    var body: some View {
        HStack(spacing: 2) {
            ToolbarIconButton(
                systemImage: "minus.magnifyingglass",
                help: "Zoom out",
                accessibilityLabel: "Zoom out",
                isDisabled: !controller.state.hasDocument
            ) {
                controller.zoomOut()
            }

            Button {
                controller.resetZoom()
            } label: {
                Text("\(Int((controller.state.layout.fontScale * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .frame(width: 40)
                    .foregroundStyle(chrome.secondaryText)
            }
            .buttonStyle(.plain)
            .disabled(!controller.state.hasDocument)
            .help("Reset zoom to 100%")
            .accessibilityLabel("Reset zoom")

            ToolbarIconButton(
                systemImage: "plus.magnifyingglass",
                help: "Zoom in",
                accessibilityLabel: "Zoom in",
                isDisabled: !controller.state.hasDocument
            ) {
                controller.zoomIn()
            }
        }
    }
}

private struct OutlineSidebar: View {
    @Environment(\.appChromeTheme) private var chrome
    @ObservedObject var controller: DocumentWindowController
    @State private var outlineFilter = ""
    @State private var selectedItemID: OutlineItem.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "list.bullet.indent")
                    .font(.system(size: 12, weight: .semibold))
                Text("Outline")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let count = headingCount {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(chrome.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(chrome.controlBackground.opacity(0.75))
                        )
                }
            }
            .foregroundStyle(chrome.secondaryText)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11))
                    .foregroundStyle(chrome.tertiaryText)
                TextField("Filter headings", text: $outlineFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(chrome.text)
                if !outlineFilter.isEmpty {
                    Button {
                        outlineFilter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(chrome.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(chrome.controlBackground.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(chrome.separator, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            outlineContent

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(chrome.sidebarBackground)
    }

    private var headingCount: Int? {
        guard case .loaded = controller.state.content,
              let outline = controller.state.currentRenderResult?.outline,
              !outline.isEmpty else {
            return nil
        }
        return outline.count
    }

    @ViewBuilder
    private var outlineContent: some View {
        switch controller.state.content {
        case .loaded:
            if let outline = controller.state.currentRenderResult?.outline, !outline.isEmpty {
                let filteredOutline = OutlineFilter.filter(outline, query: outlineFilter)
                if filteredOutline.isEmpty {
                    OutlinePlaceholder(
                        systemImage: "magnifyingglass",
                        message: "No matching headings."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(filteredOutline) { item in
                                OutlineRow(
                                    item: item,
                                    isSelected: selectedItemID == item.id,
                                    leadingPadding: outlineLeadingPadding(for: item)
                                ) {
                                    selectedItemID = item.id
                                    controller.scrollToOutlineItem(item)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                    }
                }
            } else {
                OutlinePlaceholder(
                    systemImage: "number",
                    message: "This document has no headings."
                )
            }
        case .loading:
            HStack {
                Spacer()
                ProgressView().controlSize(.small)
                Spacer()
            }
            .padding(.top, 12)
        case .error:
            OutlinePlaceholder(
                systemImage: "exclamationmark.triangle",
                message: "Open a valid Markdown file to build an outline."
            )
        case .empty:
            OutlinePlaceholder(
                systemImage: "doc.text",
                message: "Open a Markdown document to build an outline."
            )
        }
    }

    private func outlineLeadingPadding(for item: OutlineItem) -> CGFloat {
        if outlineFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CGFloat(max(0, item.level - 1)) * 13
        }
        return 0
    }
}

private struct OutlineRow: View {
    @Environment(\.appChromeTheme) private var chrome

    let item: OutlineItem
    let isSelected: Bool
    let leadingPadding: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(chrome.accent)
                        .frame(width: 3, height: 14)
                        .padding(.trailing, leadingPadding + 6)
                } else {
                    Spacer().frame(width: leadingPadding + 9)
                }

                Text(item.title)
                    .font(.system(size: 12.5, weight: item.level <= 1 ? .semibold : .regular))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? chrome.accent : chrome.text)
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Jump to \(item.title)")
    }

    private var backgroundFill: Color {
        if isSelected {
            return chrome.accent.opacity(0.12)
        }
        if isHovering {
            return chrome.text.opacity(0.07)
        }
        return .clear
    }
}

private struct OutlinePlaceholder: View {
    @Environment(\.appChromeTheme) private var chrome

    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(chrome.tertiaryText)
            Text(message)
                .font(.callout)
                .foregroundStyle(chrome.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }
}

private struct PreviewShell: View {
    @EnvironmentObject private var appController: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appChromeTheme) private var chrome
    @ObservedObject var controller: DocumentWindowController
    let isDropTargeted: Bool

    var body: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isDropTargeted {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(chrome.accent.opacity(0.08))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(chrome.accent, style: StrokeStyle(lineWidth: 2.5, dash: [9, 7]))

                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 40, weight: .medium))
                        Text("Drop Markdown to open")
                            .font(.title3.weight(.semibold))
                    }
                    .foregroundStyle(chrome.accent)
                }
                .padding(16)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        .background(chrome.contentBackground)
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
                    .foregroundStyle(chrome.secondaryText)
            }
        case .loaded(let document):
            switch controller.state.preview {
            case .loading:
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Rendering \(document.displayName)")
                        .foregroundStyle(chrome.secondaryText)
                }
            case .rendered(let result):
                VStack(spacing: 0) {
                    if controller.state.search.isVisible {
                        FindBar(controller: controller)
                        ChromeDivider()
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
                        onRichContentRendering: { features in
                            controller.beginRichContentRendering(features: features)
                        },
                        onRichContentReady: { features in
                            controller.finishRichContentRendering(features: features)
                        },
                        onRichContentFailed: { message in
                            controller.failRichContentRendering(message: message)
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
    @Environment(\.appChromeTheme) private var chrome
    @ObservedObject var controller: DocumentWindowController
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(chrome.secondaryText)

            TextField("Find in preview", text: searchQueryBinding)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(chrome.text)
                .focused($isFocused)
                .onSubmit {
                    controller.findNext()
                }

            Text(controller.state.search.resultSummary)
                .foregroundStyle(chrome.secondaryText)
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
        .background(chrome.toolbarBackground)
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
    @Environment(\.appChromeTheme) private var chrome

    let openAction: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(chrome.accent.opacity(0.10))
                    .frame(width: 112, height: 112)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 46, weight: .regular))
                    .foregroundStyle(chrome.accent)
            }

            VStack(spacing: 8) {
                Text(AppInfo.name)
                    .font(.largeTitle.weight(.semibold))

                Text(AppInfo.summary)
                    .font(.title3)
                    .foregroundStyle(chrome.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: openAction) {
                Label("Open Markdown File", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 2)

            HStack(spacing: 18) {
                EmptyStateHint(systemImage: "command", text: "Cmd-O to open")
                EmptyStateHint(systemImage: "arrow.down.doc", text: "Drag a file here")
                EmptyStateHint(systemImage: "clock.arrow.circlepath", text: "File > Open Recent")
            }
            .padding(.top, 6)
        }
        .padding(40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Empty document")
    }
}

private struct EmptyStateHint: View {
    @Environment(\.appChromeTheme) private var chrome

    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(chrome.secondaryText)
            Text(text)
                .font(.callout)
                .foregroundStyle(chrome.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(chrome.elevatedBackground.opacity(0.72))
        )
        .overlay(
            Capsule().stroke(chrome.separator, lineWidth: 1)
        )
    }
}

private struct LoadedDocumentPlaceholder: View {
    @Environment(\.appChromeTheme) private var chrome

    let document: OpenedDocument

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(chrome.secondaryText)

            VStack(spacing: 6) {
                Text(document.displayName)
                    .font(.title.weight(.semibold))
                Text("Preview is ready.")
                    .font(.title3)
                    .foregroundStyle(chrome.secondaryText)
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
            .foregroundStyle(chrome.secondaryText)
            .padding(.top, 4)
        }
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loaded document summary")
    }
}

private struct PreviewErrorView: View {
    @Environment(\.appChromeTheme) private var chrome

    let error: PreviewError

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(chrome.warning)

            VStack(spacing: 8) {
                Text("Could Not Render Preview")
                    .font(.title.weight(.semibold))

                Text(error.message)
                    .font(.body)
                    .foregroundStyle(chrome.secondaryText)
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
    @Environment(\.appChromeTheme) private var chrome

    let error: DocumentOpenError
    let openAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(chrome.warning)

            VStack(spacing: 8) {
                Text("Could Not Open Document")
                    .font(.title.weight(.semibold))

                Text(error.message)
                    .font(.body)
                    .foregroundStyle(chrome.secondaryText)
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
    @Environment(\.appChromeTheme) private var chrome
    @ObservedObject var controller: DocumentWindowController
    @State private var isDiagnosticsPopoverPresented = false

    var body: some View {
        HStack(spacing: 16) {
            Label(statusTitle, systemImage: statusIcon)
                .foregroundStyle(chrome.secondaryText)

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
            if let richContentStatusTitle {
                StatusPill(
                    title: richContentStatusTitle,
                    systemImage: richContentStatusIcon,
                    tint: richContentStatusColor
                )
            }
            if let livePreviewStatusTitle {
                StatusPill(
                    title: livePreviewStatusTitle,
                    systemImage: livePreviewStatusIcon,
                    tint: chrome.secondaryText
                )
            }
            Label(PreviewThemeStore.theme(id: controller.state.layout.selectedThemeID).name, systemImage: "paintpalette")
                .labelStyle(.titleAndIcon)
            Text("\(Int((controller.state.layout.fontScale * 100).rounded()))%")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(chrome.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(chrome.toolbarBackground)
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

    private var richContentStatusTitle: String? {
        switch controller.state.richContentPreview {
        case .inactive:
            return nil
        case .pending, .rendering:
            return "Rich rendering"
        case .ready:
            return "Rich ready"
        case .failed:
            return "Rich failed"
        }
    }

    private var richContentStatusIcon: String {
        switch controller.state.richContentPreview {
        case .inactive, .pending:
            return "sparkles"
        case .rendering:
            return "arrow.triangle.2.circlepath"
        case .ready:
            return "checkmark.seal"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private var richContentStatusColor: Color {
        switch controller.state.richContentPreview {
        case .failed:
            return chrome.warning
        default:
            return chrome.secondaryText
        }
    }
}

private struct StatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(tint.opacity(0.12))
            )
    }
}

private struct DiagnosticsPopover: View {
    @Environment(\.appChromeTheme) private var chrome

    let diagnostics: [RenderDiagnostic]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics")
                .font(.headline)

            if diagnostics.isEmpty {
                Text("No warnings.")
                    .foregroundStyle(chrome.secondaryText)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(groupedDiagnostics) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(chrome.secondaryText)

                                ForEach(group.diagnostics) { diagnostic in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(diagnostic.severity.rawValue.capitalized, systemImage: icon(for: diagnostic))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(color(for: diagnostic))
                                        Text(diagnostic.message)
                                            .fixedSize(horizontal: false, vertical: true)
                                        if let source = diagnostic.source {
                                            Text(source)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(chrome.secondaryText)
                                                .lineLimit(3)
                                                .truncationMode(.middle)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private struct DiagnosticGroup: Identifiable {
        let id: String
        let title: String
        let diagnostics: [RenderDiagnostic]
    }

    private var groupedDiagnostics: [DiagnosticGroup] {
        var groups: [DiagnosticGroup] = []

        for diagnostic in diagnostics {
            let title = kindTitle(for: diagnostic.kind)
            if let index = groups.firstIndex(where: { $0.title == title }) {
                var groupDiagnostics = groups[index].diagnostics
                groupDiagnostics.append(diagnostic)
                groups[index] = DiagnosticGroup(id: groups[index].id, title: title, diagnostics: groupDiagnostics)
            } else {
                groups.append(DiagnosticGroup(id: diagnostic.kind.rawValue, title: title, diagnostics: [diagnostic]))
            }
        }

        return groups
    }

    private func icon(for diagnostic: RenderDiagnostic) -> String {
        switch diagnostic.kind {
        case .missingLocalImage:
            return "photo"
        case .missingLocalLink, .malformedLink, .unsupportedLinkScheme, .linkValidationSkipped:
            return "link"
        case .missingHeadingFragment:
            return "number"
        default:
            break
        }

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
            return chrome.secondaryText
        case .warning:
            return chrome.warning
        case .error:
            return .red
        }
    }

    private func kindTitle(for kind: RenderDiagnosticKind) -> String {
        switch kind {
        case .missingLocalImage:
            return "Images"
        case .missingLocalLink:
            return "Missing Links"
        case .missingHeadingFragment:
            return "Heading Links"
        case .malformedLink:
            return "Malformed Links"
        case .unsupportedLinkScheme:
            return "Unsupported Links"
        case .linkValidationSkipped:
            return "Skipped Link Checks"
        case .mermaidRenderFailure:
            return "Mermaid"
        case .mathRenderFailure:
            return "Math"
        case .richContentDisabled:
            return "Disabled Features"
        case .malformedGitHubCallout:
            return "Callouts"
        case .unsupportedExtension:
            return "Renderer Extensions"
        case .renderFailure:
            return "Rendering"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appController: AppController
    @Environment(\.appChromeTheme) private var chrome

    var body: some View {
        Form {
            Section("App Appearance") {
                Picker("App Theme", selection: settingBinding(\.appChromeThemeID)) {
                    ForEach(AppChromeThemeStore.allBuiltInThemes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .accessibilityLabel("App theme")

                AppChromeThemeGrid(selection: settingBinding(\.appChromeThemeID))
            }

            Section("Preview Defaults") {
                Picker("Render Profile", selection: renderProfileBinding) {
                    ForEach(MarkdownRenderProfile.allCases) { profile in
                        Text(profile.displayName).tag(profile)
                    }
                }
                .accessibilityLabel("Markdown render profile")

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

            Section("Rich Markdown") {
                Toggle("Mermaid diagrams", isOn: richMarkdownBinding(\.rendersMermaid))
                Toggle("KaTeX math", isOn: richMarkdownBinding(\.rendersMath))
                Toggle("GitHub callouts", isOn: richMarkdownBinding(\.rendersGitHubCallouts))
            }

            Section("Link Validation") {
                Toggle("Local links", isOn: richMarkdownBinding(\.validatesLocalLinks))
                Toggle("Heading links", isOn: richMarkdownBinding(\.validatesHeadingFragments))
                Toggle("Report remote links", isOn: richMarkdownBinding(\.validatesRemoteLinks))
                    .help("Remote URLs are parsed for manual checks; preview rendering does not crawl remote servers.")
            }

            Section("Export") {
                Toggle("Embed CSS in HTML export", isOn: settingBinding(\.embedsCSSInHTMLExport))
                Toggle("Embed local images in HTML export", isOn: settingBinding(\.embedsLocalImagesInHTMLExport))
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 560)
        .background(chrome.windowBackground)
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

    private var renderProfileBinding: Binding<MarkdownRenderProfile> {
        Binding(
            get: { appController.settings.renderProfile },
            set: { newValue in
                appController.updateSettings { settings in
                    settings.renderProfile = newValue
                    settings.richMarkdownOptions = newValue.defaultRichMarkdownOptions
                }
            }
        )
    }

    private func richMarkdownBinding(_ keyPath: WritableKeyPath<RichMarkdownOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { appController.settings.richMarkdownOptions[keyPath: keyPath] },
            set: { newValue in
                appController.updateSettings { settings in
                    settings.richMarkdownOptions[keyPath: keyPath] = newValue
                }
            }
        )
    }
}

private struct AppChromeThemeGrid: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 148), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(AppChromeThemeStore.allBuiltInThemes) { theme in
                AppChromeThemeButton(
                    theme: theme,
                    isSelected: selection == theme.id
                ) {
                    selection = theme.id
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct AppChromeThemeButton: View {
    @Environment(\.appChromeTheme) private var chrome

    let theme: AppChromeTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    AppChromePaletteStrip(palette: theme.lightPalette)
                    AppChromePaletteStrip(palette: theme.darkPalette)
                }

                HStack(spacing: 6) {
                    Text(theme.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 4)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? chrome.accent : chrome.tertiaryText)
                }

                Text("\(theme.lightVariantName) / \(theme.darkVariantName)")
                    .font(.caption2)
                    .foregroundStyle(chrome.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? chrome.accent.opacity(0.12) : chrome.elevatedBackground.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? chrome.accent : chrome.separator, lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AppChromePaletteStrip: View {
    let palette: AppChromePalette

    var body: some View {
        HStack(spacing: 0) {
            Color(omHexRGB: palette.toolbarBackgroundHex)
            Color(omHexRGB: palette.contentBackgroundHex)
            Color(omHexRGB: palette.accentHex)
        }
        .frame(height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color(omHexRGB: palette.separatorHex), lineWidth: 1)
        )
    }
}
