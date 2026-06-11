import AppKit
import SwiftUI
import OpenMarkedCore

private let inspectorInitialDisplayLimit = 250

struct InspectorSidebar: View {
    @Environment(\.appChromeTheme) private var chrome
    @ObservedObject var controller: DocumentWindowController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Picker("Inspector section", selection: sectionBinding) {
                ForEach(DocumentInspectorSection.allCases) { section in
                    Image(systemName: section.systemImage)
                        .tag(section)
                        .accessibilityLabel(section.title)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .help(controller.state.layout.selectedInspectorSection.title)

            InspectorDivider()

            inspectorContent
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(chrome.sidebarBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document inspector")
    }

    private var sectionBinding: Binding<DocumentInspectorSection> {
        Binding(
            get: { controller.state.layout.selectedInspectorSection },
            set: { controller.showInspector(section: $0) }
        )
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 12, weight: .semibold))
            Text("Inspector")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                controller.setInspectorVisible(false)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(chrome.tertiaryText)
            .help("Hide inspector")
            .accessibilityLabel("Hide inspector")
        }
        .foregroundStyle(chrome.secondaryText)
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch controller.state.content {
        case .empty:
            InspectorPlaceholder(
                systemImage: "doc.text",
                title: "No Document",
                message: "Open a document to inspect it."
            )
        case .loading:
            VStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text("Opening")
                    .font(.callout)
                    .foregroundStyle(chrome.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
        case .error:
            InspectorPlaceholder(
                systemImage: "exclamationmark.triangle",
                title: "Open Error",
                message: "The document could not be inspected."
            )
        case .loaded:
            if let report = controller.state.currentInspectionReport {
                ScrollView {
                    sectionContent(report)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
            } else {
                InspectorPlaceholder(
                    systemImage: "doc.text.magnifyingglass",
                    title: "Inspector",
                    message: "No inspection report is available."
                )
            }
        }
    }

    @ViewBuilder
    private func sectionContent(_ report: DocumentInspectionReport) -> some View {
        switch controller.state.layout.selectedInspectorSection {
        case .summary:
            SummaryInspectorSection(report: report)
        case .metadata:
            MetadataInspectorSection(report: report)
        case .links:
            LinksInspectorSection(report: report, controller: controller)
        case .assets:
            AssetsInspectorSection(report: report)
        case .diagnostics:
            DiagnosticsInspectorSection(report: report, controller: controller)
        case .statistics:
            StatisticsInspectorSection(report: report)
        case .export:
            ExportInspectorSection(report: report)
        }
    }
}

private struct SummaryInspectorSection: View {
    let report: DocumentInspectionReport

    var body: some View {
        InspectorSectionStack(title: "Summary") {
            InspectorTitleBlock(
                title: report.metadata.displayTitle,
                subtitle: report.metadata.titleSource.title
            )

            InspectorMetricGrid(
                metrics: [
                    InspectorMetric(title: "Words", value: "\(report.statistics.words)", systemImage: "text.alignleft"),
                    InspectorMetric(title: "Headings", value: "\(report.statistics.headingCount)", systemImage: "list.bullet.indent"),
                    InspectorMetric(title: "Links", value: "\(report.statistics.linkCount)", systemImage: "link"),
                    InspectorMetric(title: "Assets", value: "\(report.statistics.imageCount)", systemImage: "photo"),
                    InspectorMetric(title: "Diagnostics", value: "\(report.diagnostics.count)", systemImage: "exclamationmark.triangle"),
                    InspectorMetric(title: "Export", value: exportSummary, systemImage: "square.and.arrow.up")
                ]
            )
        }
    }

    private var exportSummary: String {
        if report.exportReadiness.issues.isEmpty {
            return "Ready"
        }
        if report.exportReadiness.isReady {
            return "Notes"
        }
        return "\(report.exportReadiness.issues.count) issues"
    }
}

private struct MetadataInspectorSection: View {
    let report: DocumentInspectionReport

    var body: some View {
        InspectorSectionStack(title: "Metadata") {
            InspectorTitleBlock(
                title: report.metadata.displayTitle,
                subtitle: report.metadata.frontMatterFormat?.rawValue.uppercased() ?? "No front matter"
            )

            InspectorFieldGroup(
                title: "Document Title",
                fields: [
                    MetadataField(key: "resolvedTitle", label: "Title", value: report.metadata.displayTitle, source: .file, isStandard: true),
                    MetadataField(key: "titleSource", label: "Source", value: report.metadata.titleSource.title, source: .file, isStandard: true)
                ]
            )

            let frontMatterDiagnostics = report.diagnostics.filter { $0.kind == .malformedFrontMatter }
            if !frontMatterDiagnostics.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Front Matter Diagnostics")
                        .font(.caption.weight(.semibold))
                    ForEach(frontMatterDiagnostics) { diagnostic in
                        InspectorDiagnosticRow(diagnostic: diagnostic)
                    }
                }
            }

            let standardFields = report.metadata.fields.filter(\.isStandard)
            let customFields = report.metadata.fields.filter { !$0.isStandard }

            if report.metadata.frontMatterFormat == nil {
                InlineEmptyState(systemImage: "tag", message: "No front matter.")
            } else if report.metadata.fields.isEmpty {
                InlineEmptyState(systemImage: "tag", message: "No readable front matter fields.")
            } else {
                if !standardFields.isEmpty {
                    InspectorFieldGroup(title: "Standard Fields", fields: standardFields)
                }
                if !customFields.isEmpty {
                    InspectorFieldGroup(title: "Custom Fields", fields: customFields)
                }
            }

            InspectorFieldGroup(title: "File", fields: report.metadata.fileFacts)
        }
    }
}

private struct LinksInspectorSection: View {
    let report: DocumentInspectionReport
    let controller: DocumentWindowController

    @State private var typeFilter: InspectorLinkTypeFilter = .all
    @State private var statusFilter: InspectorReferenceStatusFilter = .all
    @State private var showsAllLinks = false

    var body: some View {
        let matchingLinks = filteredLinks
        let displayedLinks = visibleLinks(from: matchingLinks)
        let lastVisibleLinkID = displayedLinks.last?.id

        InspectorSectionStack(title: "Links") {
            InspectorFilterControls {
                Picker("Type", selection: $typeFilter) {
                    ForEach(InspectorLinkTypeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("Status", selection: $statusFilter) {
                    ForEach(InspectorReferenceStatusFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }

            if report.links.isEmpty {
                InlineEmptyState(systemImage: "link", message: "No rendered links.")
            } else if matchingLinks.isEmpty {
                InlineEmptyState(systemImage: "line.3.horizontal.decrease.circle", message: "No links match the filters.")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(displayedLinks) { link in
                        InspectorReferenceRow(
                            title: link.text.isEmpty ? link.target : link.text,
                            subtitle: linkSubtitle(link),
                            systemImage: link.kind.systemImage,
                            status: link.status,
                            diagnosticsCount: link.diagnostics.count,
                            kindTitle: link.kind.title,
                            subtitleLineLimit: 3,
                            actions: inspectorActions(for: link, controller: controller)
                        )
                        if link.id != lastVisibleLinkID {
                            InspectorDivider()
                        }
                    }
                }
                largeListButton(
                    visibleCount: displayedLinks.count,
                    totalCount: matchingLinks.count,
                    noun: "links",
                    isShowingAll: $showsAllLinks
                )
            }
        }
    }

    private var filteredLinks: [DocumentLinkReference] {
        report.links.filter { link in
            typeFilter.matches(link.kind) && statusFilter.matches(link.status)
        }
    }

    private func visibleLinks(from filteredLinks: [DocumentLinkReference]) -> [DocumentLinkReference] {
        showsAllLinks ? filteredLinks : Array(filteredLinks.prefix(inspectorInitialDisplayLimit))
    }

    private func linkSubtitle(_ link: DocumentLinkReference) -> String {
        var lines = [link.target]
        if let resolvedPath = link.resolvedPath {
            lines.append("Resolved: \(resolvedPath)")
        }
        if link.kind == .remoteURL {
            lines.append("Remote URL parsed; not crawled.")
        }
        return lines.joined(separator: "\n")
    }
}

private struct AssetsInspectorSection: View {
    let report: DocumentInspectionReport
    @State private var typeFilter: InspectorAssetTypeFilter = .all
    @State private var statusFilter: InspectorReferenceStatusFilter = .all
    @State private var showsAllAssets = false

    var body: some View {
        let matchingAssets = filteredAssets
        let displayedAssets = visibleAssets(from: matchingAssets)
        let lastVisibleAssetID = displayedAssets.last?.id

        InspectorSectionStack(title: "Assets") {
            InspectorFilterControls {
                Picker("Type", selection: $typeFilter) {
                    ForEach(InspectorAssetTypeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("Status", selection: $statusFilter) {
                    ForEach(InspectorReferenceStatusFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }

            if report.assets.isEmpty {
                InlineEmptyState(systemImage: "photo", message: "No rendered images.")
            } else if matchingAssets.isEmpty {
                InlineEmptyState(systemImage: "line.3.horizontal.decrease.circle", message: "No assets match the filters.")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(displayedAssets) { asset in
                        InspectorReferenceRow(
                            title: asset.altText.isEmpty ? asset.kind.title : asset.altText,
                            subtitle: assetSubtitle(asset),
                            systemImage: asset.kind.systemImage,
                            status: asset.status,
                            diagnosticsCount: asset.diagnostics.count,
                            kindTitle: asset.kind.title,
                            subtitleLineLimit: 4,
                            actions: inspectorActions(for: asset)
                        )
                        if asset.id != lastVisibleAssetID {
                            InspectorDivider()
                        }
                    }
                }
                largeListButton(
                    visibleCount: displayedAssets.count,
                    totalCount: matchingAssets.count,
                    noun: "assets",
                    isShowingAll: $showsAllAssets
                )
            }
        }
    }

    private var filteredAssets: [DocumentAssetReference] {
        report.assets.filter { asset in
            typeFilter.matches(asset) && statusFilter.matches(asset.status)
        }
    }

    private func visibleAssets(from filteredAssets: [DocumentAssetReference]) -> [DocumentAssetReference] {
        showsAllAssets ? filteredAssets : Array(filteredAssets.prefix(inspectorInitialDisplayLimit))
    }

    private func assetSubtitle(_ asset: DocumentAssetReference) -> String {
        var lines = [asset.source]
        if let resolvedPath = asset.resolvedPath {
            lines.append("Resolved: \(resolvedPath)")
        }
        if let fileInfo = asset.fileInfo {
            lines.append(fileInfo.displayTitle)
        }
        if asset.status == .blocked {
            lines.append("Remote image blocked by content setting.")
        }
        return lines.joined(separator: "\n")
    }
}

private struct DiagnosticsInspectorSection: View {
    let report: DocumentInspectionReport
    let controller: DocumentWindowController

    @State private var searchQuery = ""
    @State private var severityFilter: InspectorDiagnosticSeverityFilter = .all
    @State private var showsAllDiagnostics = false

    var body: some View {
        let matchingDiagnostics = filteredDiagnostics
        let displayedDiagnostics = visibleDiagnostics(from: matchingDiagnostics)
        let diagnosticGroups = groupedDiagnostics(from: displayedDiagnostics)

        InspectorSectionStack(title: "Diagnostics") {
            InspectorFilterControls {
                TextField("Search diagnostics", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)

                Picker("Severity", selection: $severityFilter) {
                    ForEach(InspectorDiagnosticSeverityFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }

            if report.diagnostics.isEmpty {
                InlineEmptyState(systemImage: "checkmark.circle", message: "No diagnostics.")
            } else if diagnosticGroups.isEmpty {
                InlineEmptyState(systemImage: "line.3.horizontal.decrease.circle", message: "No diagnostics match the filters.")
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(diagnosticGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(group.tint(chrome: chrome))
                                .textCase(.uppercase)

                            LazyVStack(spacing: 0) {
                                let lastDiagnosticID = group.diagnostics.last?.id
                                ForEach(group.diagnostics) { diagnostic in
                                    InspectorDiagnosticRow(
                                        diagnostic: diagnostic,
                                        actions: inspectorActions(
                                            for: diagnostic,
                                            report: report,
                                            controller: controller
                                        )
                                    )
                                    if diagnostic.id != lastDiagnosticID {
                                        InspectorDivider()
                                    }
                                }
                            }
                        }
                    }
                }
                largeListButton(
                    visibleCount: displayedDiagnostics.count,
                    totalCount: matchingDiagnostics.count,
                    noun: "diagnostics",
                    isShowingAll: $showsAllDiagnostics
                )
            }
        }
    }

    @Environment(\.appChromeTheme) private var chrome

    private var filteredDiagnostics: [RenderDiagnostic] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return report.diagnostics.filter { diagnostic in
            severityFilter.matches(diagnostic.severity)
                && (query.isEmpty || diagnostic.matches(query: query))
        }
    }

    private func visibleDiagnostics(from filteredDiagnostics: [RenderDiagnostic]) -> [RenderDiagnostic] {
        showsAllDiagnostics ? filteredDiagnostics : Array(filteredDiagnostics.prefix(inspectorInitialDisplayLimit))
    }

    private func groupedDiagnostics(from visibleDiagnostics: [RenderDiagnostic]) -> [InspectorDiagnosticGroup] {
        let groups = Dictionary(grouping: visibleDiagnostics) { diagnostic in
            InspectorDiagnosticGroupKey(kind: diagnostic.kind, severity: diagnostic.severity)
        }

        return groups.keys.sorted().map { key in
            InspectorDiagnosticGroup(
                key: key,
                diagnostics: groups[key]?.sorted { $0.id < $1.id } ?? []
            )
        }
    }
}

@MainActor
private func largeListButton(
    visibleCount: Int,
    totalCount: Int,
    noun: String,
    isShowingAll: Binding<Bool>
) -> some View {
    Group {
        if totalCount > visibleCount {
            Button {
                isShowingAll.wrappedValue = true
            } label: {
                Label("Show all \(totalCount) \(noun)", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .padding(.top, 4)
            .help("Showing the first \(visibleCount) \(noun) for smoother inspector performance.")
        }
    }
}

private struct StatisticsInspectorSection: View {
    let report: DocumentInspectionReport

    var body: some View {
        InspectorSectionStack(title: "Statistics") {
            InspectorMetricGrid(
                metrics: [
                    InspectorMetric(title: "Words", value: "\(report.statistics.words)", systemImage: "text.alignleft", help: statisticsScopeHelp),
                    InspectorMetric(title: "Read Time", value: "\(report.statistics.readingTimeMinutes)m", systemImage: "clock", help: "Estimated at \(report.statistics.wordsPerMinute) words per minute."),
                    InspectorMetric(title: "Pages", value: "\(report.statistics.estimatedPageCount)", systemImage: "doc.text", help: "Estimated PDF pages based on words and rich content."),
                    InspectorMetric(title: "Sections", value: "\(report.statistics.sectionStatistics.count)", systemImage: "list.bullet.indent", help: "Markdown headings with section-level counts."),
                    InspectorMetric(title: "Paragraphs", value: "\(report.statistics.paragraphCount)", systemImage: "paragraphsign", help: "Rendered paragraph elements."),
                    InspectorMetric(title: "Links", value: "\(report.statistics.linkCount)", systemImage: "link", help: "Rendered document links."),
                    InspectorMetric(title: "Images", value: "\(report.statistics.imageCount)", systemImage: "photo", help: "Rendered image references."),
                    InspectorMetric(title: "Tables", value: "\(report.statistics.tableCount)", systemImage: "tablecells", help: "Rendered tables."),
                    InspectorMetric(title: "Code", value: "\(report.statistics.codeBlockCount)", systemImage: "chevron.left.forwardslash.chevron.right", help: "Fenced code blocks."),
                    InspectorMetric(title: "Callouts", value: "\(report.statistics.calloutCount)", systemImage: "quote.bubble", help: "GitHub-style callout blocks."),
                    InspectorMetric(title: "Mermaid", value: "\(report.statistics.mermaidDiagramCount)", systemImage: "point.3.connected.trianglepath.dotted", help: "Mermaid diagram blocks."),
                    InspectorMetric(title: "Math", value: "\(report.statistics.mathExpressionCount)", systemImage: "function", help: "KaTeX math expressions."),
                    InspectorMetric(title: "Warnings", value: "\(report.statistics.missingReferenceCount)", systemImage: "exclamationmark.triangle", help: "Missing or malformed references."),
                    InspectorMetric(title: "Diagnostics", value: "\(report.statistics.diagnosticCount)", systemImage: "stethoscope", help: "Renderer and document diagnostics.")
                ]
            )

            if let longestSection = report.statistics.longestSection {
                InspectorSectionHighlight(section: longestSection)
            }

            if !report.statistics.headingLevels.isEmpty {
                InspectorFieldGroup(
                    title: "Heading Levels",
                    fields: report.statistics.headingLevels
                        .sorted { $0.key < $1.key }
                        .map { level, count in
                            MetadataField(
                                key: "h\(level)",
                                label: "H\(level)",
                                value: "\(count)",
                                source: .file,
                                isStandard: true
                            )
                        }
                )
            }

            InspectorSectionStatisticsGroup(sections: report.statistics.sectionStatistics)
        }
    }

    private var statisticsScopeHelp: String {
        report.statistics.includesFrontMatter
            ? "Word, character, line, and reading-time counts include front matter."
            : "Word, character, line, and reading-time counts exclude front matter."
    }
}

private struct ExportInspectorSection: View {
    let report: DocumentInspectionReport

    var body: some View {
        let orderedIssues = sortedIssues
        let lastIssueID = orderedIssues.last?.id

        InspectorSectionStack(title: "Export") {
            InspectorMetricGrid(
                metrics: [
                    InspectorMetric(title: "Warnings", value: "\(warningCount)", systemImage: "exclamationmark.triangle", help: "Warnings likely to affect export or print."),
                    InspectorMetric(title: "Notes", value: "\(infoCount)", systemImage: "info.circle", help: "Informational export notes."),
                    InspectorMetric(title: "Pages", value: "\(report.statistics.estimatedPageCount)", systemImage: "doc.text", help: "Estimated PDF page count."),
                    InspectorMetric(title: "Wide Tables", value: "\(report.statistics.wideTableCandidateCount)", systemImage: "tablecells", help: "Tables that may need print review.")
                ]
            )

            InspectorReferenceRow(
                title: report.exportReadiness.isReady ? "Ready" : "Needs Review",
                subtitle: report.exportReadiness.issues.isEmpty ? "No readiness issues." : "\(report.exportReadiness.issues.count) readiness issue\(report.exportReadiness.issues.count == 1 ? "" : "s"). Export remains available.",
                systemImage: report.exportReadiness.isReady ? "checkmark.circle" : "exclamationmark.triangle",
                status: report.exportReadiness.isReady ? .valid : .warning,
                diagnosticsCount: 0
            )

            if report.exportReadiness.issues.isEmpty {
                InlineEmptyState(systemImage: "square.and.arrow.up", message: "No export readiness issues.")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(orderedIssues) { issue in
                        InspectorIssueRow(issue: issue)
                        if issue.id != lastIssueID {
                            InspectorDivider()
                        }
                    }
                }
            }
        }
    }

    private var warningCount: Int {
        report.exportReadiness.issues.filter { $0.severity != .info }.count
    }

    private var infoCount: Int {
        report.exportReadiness.issues.filter { $0.severity == .info }.count
    }

    private var sortedIssues: [ExportReadinessIssue] {
        report.exportReadiness.issues.sorted { left, right in
            if left.severity.sortPriority == right.severity.sortPriority {
                return left.title < right.title
            }
            return left.severity.sortPriority < right.severity.sortPriority
        }
    }
}

private struct InspectorRowAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void

    static func copy(title: String, value: String) -> InspectorRowAction {
        InspectorRowAction(id: "copy:\(value)", title: title, systemImage: "doc.on.doc") {
            copyToPasteboard(value)
        }
    }
}

private enum InspectorReferenceStatusFilter: String, CaseIterable, Identifiable {
    case all
    case valid
    case review
    case skipped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All Status"
        case .valid:
            return "Valid"
        case .review:
            return "Review"
        case .skipped:
            return "Skipped"
        }
    }

    func matches(_ status: DocumentReferenceStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .valid:
            return status == .valid
        case .review:
            return [.warning, .missing, .malformed, .unsupported, .blocked].contains(status)
        case .skipped:
            return status == .skipped
        }
    }
}

private enum InspectorLinkTypeFilter: String, CaseIterable, Identifiable {
    case all
    case heading
    case local
    case remote
    case contact
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All Links"
        case .heading:
            return "Headings"
        case .local:
            return "Local"
        case .remote:
            return "Remote"
        case .contact:
            return "Contact"
        case .other:
            return "Other"
        }
    }

    func matches(_ kind: DocumentReferenceKind) -> Bool {
        switch self {
        case .all:
            return true
        case .heading:
            return kind == .sameDocumentHeading
        case .local:
            return kind == .localFile
        case .remote:
            return kind == .remoteURL
        case .contact:
            return kind == .email || kind == .telephone
        case .other:
            return [.unsupportedScheme, .malformed, .unknown].contains(kind)
        }
    }
}

private enum InspectorAssetTypeFilter: String, CaseIterable, Identifiable {
    case all
    case local
    case remote
    case embedded
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All Assets"
        case .local:
            return "Local"
        case .remote:
            return "Remote"
        case .embedded:
            return "Embedded"
        case .review:
            return "Review"
        }
    }

    func matches(_ asset: DocumentAssetReference) -> Bool {
        switch self {
        case .all:
            return true
        case .local:
            return asset.kind == .localImage
        case .remote:
            return asset.kind == .remoteImage
        case .embedded:
            return asset.kind == .dataImage
        case .review:
            return [.missing, .blocked, .unsupported, .malformed, .warning].contains(asset.status)
        }
    }
}

private enum InspectorDiagnosticSeverityFilter: String, CaseIterable, Identifiable {
    case all
    case warning
    case info
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All Severity"
        case .warning:
            return "Warnings"
        case .info:
            return "Info"
        case .error:
            return "Errors"
        }
    }

    func matches(_ severity: RenderDiagnosticSeverity) -> Bool {
        switch self {
        case .all:
            return true
        case .warning:
            return severity == .warning
        case .info:
            return severity == .info
        case .error:
            return severity == .error
        }
    }
}

private struct InspectorDiagnosticGroupKey: Hashable, Comparable {
    let kindRawValue: String
    let kindTitle: String
    let severityRawValue: String
    let severityTitle: String
    let severityPriority: Int

    init(kind: RenderDiagnosticKind, severity: RenderDiagnosticSeverity) {
        self.kindRawValue = kind.rawValue
        self.kindTitle = DiagnosticDisplayMetadata.kindTitle(for: kind)
        self.severityRawValue = severity.rawValue
        self.severityTitle = DiagnosticDisplayMetadata.severityTitle(for: severity)
        self.severityPriority = DiagnosticDisplayMetadata.sortPriority(for: severity)
    }

    static func < (left: InspectorDiagnosticGroupKey, right: InspectorDiagnosticGroupKey) -> Bool {
        if left.severityPriority == right.severityPriority {
            return left.kindTitle < right.kindTitle
        }
        return left.severityPriority < right.severityPriority
    }
}

private struct InspectorDiagnosticGroup: Identifiable {
    let key: InspectorDiagnosticGroupKey
    let diagnostics: [RenderDiagnostic]

    var id: String {
        "\(key.severityRawValue):\(key.kindRawValue)"
    }

    var title: String {
        "\(key.severityTitle) - \(key.kindTitle)"
    }

    func tint(chrome: ResolvedAppChromeTheme) -> Color {
        DiagnosticDisplayMetadata.tint(
            for: RenderDiagnosticSeverity(rawValue: key.severityRawValue) ?? .info,
            chrome: chrome,
            context: .group
        )
    }
}

private struct InspectorSectionStack<Content: View>: View {
    @ViewBuilder let content: Content
    let title: String

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            content
        }
    }
}

private struct InspectorTitleBlock: View {
    @Environment(\.appChromeTheme) private var chrome

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(chrome.text)
                .lineLimit(3)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(chrome.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }
}

private struct InspectorMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    let help: String

    init(title: String, value: String, systemImage: String, help: String? = nil) {
        self.id = "\(title):\(value):\(systemImage)"
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.help = help ?? "\(title): \(value)"
    }
}

private struct InspectorMetricGrid: View {
    private let columns = [
        GridItem(.flexible(minimum: 92), spacing: 8),
        GridItem(.flexible(minimum: 92), spacing: 8)
    ]

    let metrics: [InspectorMetric]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(metrics) { metric in
                InspectorMetricCell(metric: metric)
            }
        }
    }
}

private struct InspectorMetricCell: View {
    @Environment(\.appChromeTheme) private var chrome

    let metric: InspectorMetric

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: metric.systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(chrome.accent)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.value)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(metric.title)
                    .font(.caption2)
                    .foregroundStyle(chrome.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(chrome.controlBackground.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(chrome.separator.opacity(0.8), lineWidth: 1)
        )
        .help(metric.help)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.title), \(metric.value)")
    }
}

private struct InspectorFilterControls<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InspectorSectionHighlight: View {
    @Environment(\.appChromeTheme) private var chrome

    let section: DocumentSectionStatistic

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Longest Section")
                .font(.caption.weight(.semibold))
                .foregroundStyle(chrome.secondaryText)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "text.badge.star")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(chrome.accent)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(chrome.text)
                        .lineLimit(2)
                    Text("H\(section.level) - \(section.wordCount) words - \(section.paragraphCount) paragraph\(section.paragraphCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(chrome.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 7)
        }
        .help("Longest section by word count.")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Longest section \(section.title), \(section.wordCount) words")
    }
}

private struct InspectorSectionStatisticsGroup: View {
    @Environment(\.appChromeTheme) private var chrome

    let sections: [DocumentSectionStatistic]
    @State private var showsAllSections = false

    var body: some View {
        let displayedSections = visibleSections
        let lastVisibleSectionID = displayedSections.last?.id

        VStack(alignment: .leading, spacing: 6) {
            Text("Sections")
                .font(.caption.weight(.semibold))
                .foregroundStyle(chrome.secondaryText)
                .textCase(.uppercase)

            if sections.isEmpty {
                InlineEmptyState(systemImage: "list.bullet.indent", message: "No headings found.")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(displayedSections) { section in
                        InspectorSectionStatisticRow(section: section)
                        if section.id != lastVisibleSectionID {
                            InspectorDivider()
                        }
                    }
                }
                largeListButton(
                    visibleCount: displayedSections.count,
                    totalCount: sections.count,
                    noun: "sections",
                    isShowingAll: $showsAllSections
                )
            }
        }
    }

    private var visibleSections: [DocumentSectionStatistic] {
        showsAllSections ? sections : Array(sections.prefix(inspectorInitialDisplayLimit))
    }
}

private struct InspectorSectionStatisticRow: View {
    @Environment(\.appChromeTheme) private var chrome

    let section: DocumentSectionStatistic

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("H\(section.level)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(chrome.accent)
                .frame(width: 24, alignment: .leading)
                .padding(.top, 1)

            Text(section.title)
                .font(.caption)
                .foregroundStyle(chrome.text)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(section.wordCount)w")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(chrome.text)
                Text("\(section.paragraphCount)p")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(chrome.secondaryText)
            }
        }
        .padding(.vertical, 6)
        .help("\(section.title): \(section.wordCount) words, \(section.paragraphCount) paragraphs.")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Section \(section.title), heading level \(section.level), \(section.wordCount) words, \(section.paragraphCount) paragraphs")
    }
}

private struct InspectorFieldGroup: View {
    @Environment(\.appChromeTheme) private var chrome

    let title: String
    let fields: [MetadataField]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(chrome.secondaryText)
                .textCase(.uppercase)

            LazyVStack(spacing: 0) {
                ForEach(fields) { field in
                    InspectorKeyValueRow(field: field)
                    if field.id != fields.last?.id {
                        InspectorDivider()
                    }
                }
            }
        }
    }
}

private struct InspectorKeyValueRow: View {
    @Environment(\.appChromeTheme) private var chrome

    let field: MetadataField

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(field.label)
                .font(.caption)
                .foregroundStyle(chrome.secondaryText)
                .frame(width: 82, alignment: .leading)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 5) {
                if field.valueKind == .list, !field.tokens.isEmpty {
                    MetadataTokenFlow(tokens: field.tokens)
                } else {
                    Text(field.value)
                        .font(.caption)
                        .foregroundStyle(chrome.text)
                        .lineLimit(field.key == "path" || field.key == "directory" ? 4 : 3)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(field.value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(chrome.tertiaryText)
            .help("Copy \(field.label)")
            .accessibilityLabel("Copy \(field.label)")
        }
        .padding(.vertical, 6)
    }
}

private struct MetadataTokenFlow: View {
    @Environment(\.appChromeTheme) private var chrome

    let tokens: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(tokens, id: \.self) { token in
                Text(token)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(chrome.text)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(chrome.controlBackground.opacity(0.75))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(chrome.separator, lineWidth: 1)
                    )
            }
        }
    }
}

private struct InspectorReferenceRow: View {
    @Environment(\.appChromeTheme) private var chrome

    let title: String
    let subtitle: String
    let systemImage: String
    let status: DocumentReferenceStatus
    let diagnosticsCount: Int
    var kindTitle: String? = nil
    var subtitleLineLimit = 2
    var actions: [InspectorRowAction] = []

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(status.tint(chrome: chrome))
                .frame(width: 18, height: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if let kindTitle {
                        InspectorBadge(title: kindTitle, tint: chrome.secondaryText)
                    }
                    InspectorBadge(title: status.title, tint: status.tint(chrome: chrome))
                    ForEach(actions) { rowAction in
                        Button(action: rowAction.action) {
                            Image(systemName: rowAction.systemImage)
                                .font(.system(size: 10.5, weight: .medium))
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(chrome.tertiaryText)
                        .help(rowAction.title)
                        .accessibilityLabel(rowAction.title)
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(chrome.secondaryText)
                    .lineLimit(subtitleLineLimit)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                if diagnosticsCount > 0 {
                    Text("\(diagnosticsCount) diagnostic\(diagnosticsCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(chrome.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
    }
}

private struct InspectorDiagnosticRow: View {
    @Environment(\.appChromeTheme) private var chrome

    let diagnostic: RenderDiagnostic
    var actions: [InspectorRowAction] = []

    var body: some View {
        InspectorReferenceRow(
            title: DiagnosticDisplayMetadata.kindTitle(for: diagnostic.kind),
            subtitle: diagnostic.source.map { "\(diagnostic.message) (\($0))" } ?? diagnostic.message,
            systemImage: DiagnosticDisplayMetadata.iconName(for: diagnostic),
            status: diagnostic.severity == .warning ? .warning : .skipped,
            diagnosticsCount: 0,
            kindTitle: DiagnosticDisplayMetadata.severityTitle(for: diagnostic.severity),
            subtitleLineLimit: 4,
            actions: actions
        )
        .accessibilityLabel("\(diagnostic.severity.rawValue) diagnostic")
    }
}

private struct InspectorIssueRow: View {
    let issue: ExportReadinessIssue

    var body: some View {
        InspectorReferenceRow(
            title: issue.title,
            subtitle: issue.source.map { "\(issue.message) (\($0))" } ?? issue.message,
            systemImage: issue.severity == .warning ? "exclamationmark.triangle" : "info.circle",
            status: issue.severity == .warning ? .warning : .skipped,
            diagnosticsCount: 0,
            kindTitle: issue.severity.title,
            subtitleLineLimit: 4,
            actions: issue.source.map {
                [InspectorRowAction.copy(title: "Copy issue source", value: $0)]
            } ?? []
        )
    }
}

private struct InspectorBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct InlineEmptyState: View {
    @Environment(\.appChromeTheme) private var chrome

    let systemImage: String
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
            Text(message)
                .font(.callout)
        }
        .foregroundStyle(chrome.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

private struct InspectorPlaceholder: View {
    @Environment(\.appChromeTheme) private var chrome

    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(chrome.tertiaryText)
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(chrome.text)
            Text(message)
                .font(.callout)
                .foregroundStyle(chrome.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 30)
    }
}

private struct InspectorDivider: View {
    @Environment(\.appChromeTheme) private var chrome

    var body: some View {
        Rectangle()
            .fill(chrome.separator)
            .frame(height: 1)
    }
}

@MainActor
private func inspectorActions(
    for link: DocumentLinkReference,
    controller: DocumentWindowController
) -> [InspectorRowAction] {
    var actions: [InspectorRowAction] = []

    if let fragment = link.fragment,
       let outlineItem = controller.state.currentRenderResult?.outline.first(where: { $0.id == fragment }) {
        actions.append(
            InspectorRowAction(id: "jump:\(outlineItem.id)", title: "Jump to heading", systemImage: "arrow.right.circle") {
                Task { @MainActor in
                    controller.scrollToOutlineItem(outlineItem)
                }
            }
        )
    }

    switch link.kind {
    case .remoteURL, .email, .telephone:
        if let url = URL(string: link.target) {
            actions.append(
                InspectorRowAction(id: "open-url:\(link.target)", title: "Open link", systemImage: "arrow.up.right.square") {
                    NSWorkspace.shared.open(url)
                }
            )
        }
    case .localFile:
        if let path = link.resolvedPath, FileManager.default.fileExists(atPath: path) {
            actions.append(contentsOf: localFileActions(path: path))
        }
    default:
        break
    }

    actions.append(.copy(title: "Copy link target", value: link.target))
    return uniqueActions(actions)
}

private func inspectorActions(for asset: DocumentAssetReference) -> [InspectorRowAction] {
    var actions: [InspectorRowAction] = []

    if asset.kind == .remoteImage, let url = URL(string: asset.source) {
        actions.append(
            InspectorRowAction(id: "open-asset-url:\(asset.source)", title: "Open image URL", systemImage: "arrow.up.right.square") {
                NSWorkspace.shared.open(url)
            }
        )
    }

    if let path = asset.resolvedPath, FileManager.default.fileExists(atPath: path) {
        actions.append(contentsOf: localFileActions(path: path))
    }

    actions.append(.copy(title: "Copy asset source", value: asset.source))
    return uniqueActions(actions)
}

@MainActor
private func inspectorActions(
    for diagnostic: RenderDiagnostic,
    report: DocumentInspectionReport,
    controller: DocumentWindowController
) -> [InspectorRowAction] {
    guard let source = diagnostic.source else {
        return []
    }

    var actions: [InspectorRowAction] = []
    if let link = report.links.first(where: { $0.target == source }) {
        actions.append(contentsOf: inspectorActions(for: link, controller: controller).filter { !$0.id.hasPrefix("copy:") })
    }
    if let asset = report.assets.first(where: { $0.source == source }) {
        actions.append(contentsOf: inspectorActions(for: asset).filter { !$0.id.hasPrefix("copy:") })
    }
    actions.append(.copy(title: "Copy diagnostic source", value: source))
    return uniqueActions(actions)
}

private func localFileActions(path: String) -> [InspectorRowAction] {
    [
        InspectorRowAction(id: "open-file:\(path)", title: "Open file", systemImage: "arrow.up.right.square") {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        },
        InspectorRowAction(id: "reveal-file:\(path)", title: "Reveal in Finder", systemImage: "magnifyingglass") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    ]
}

private func uniqueActions(_ actions: [InspectorRowAction]) -> [InspectorRowAction] {
    var seenIDs = Set<String>()
    return actions.filter { action in
        seenIDs.insert(action.id).inserted
    }
}

private func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

private extension DocumentInspectorSection {
    var systemImage: String {
        switch self {
        case .summary:
            return "doc.text.magnifyingglass"
        case .metadata:
            return "tag"
        case .links:
            return "link"
        case .assets:
            return "photo"
        case .diagnostics:
            return "exclamationmark.triangle"
        case .statistics:
            return "chart.bar"
        case .export:
            return "square.and.arrow.up"
        }
    }
}

private extension DocumentTitleSource {
    var title: String {
        switch self {
        case .frontMatter:
            return "Front matter title"
        case .firstHeading:
            return "First heading title"
        case .fileName:
            return "File name title"
        }
    }
}

private extension DocumentReferenceKind {
    var title: String {
        switch self {
        case .sameDocumentHeading:
            return "Heading"
        case .localFile:
            return "Local"
        case .remoteURL:
            return "Remote"
        case .email:
            return "Email"
        case .telephone:
            return "Phone"
        case .unsupportedScheme:
            return "Unsupported"
        case .malformed:
            return "Malformed"
        case .unknown:
            return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .sameDocumentHeading:
            return "number"
        case .localFile:
            return "doc"
        case .remoteURL:
            return "globe"
        case .email:
            return "envelope"
        case .telephone:
            return "phone"
        case .unsupportedScheme:
            return "questionmark.diamond"
        case .malformed:
            return "exclamationmark.triangle"
        case .unknown:
            return "link"
        }
    }
}

private extension DocumentAssetFileInfo {
    var displayTitle: String {
        var values: [String] = []
        if let byteSize {
            values.append(ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file))
        }
        if let pixelWidth, let pixelHeight {
            values.append("\(pixelWidth)x\(pixelHeight) px")
        }
        return values.isEmpty ? "File details unavailable" : values.joined(separator: " - ")
    }
}

private extension DocumentAssetKind {
    var title: String {
        switch self {
        case .localImage:
            return "Local image"
        case .remoteImage:
            return "Remote image"
        case .dataImage:
            return "Embedded image"
        case .unknown:
            return "Asset"
        }
    }

    var systemImage: String {
        switch self {
        case .localImage, .dataImage:
            return "photo"
        case .remoteImage:
            return "globe"
        case .unknown:
            return "questionmark.diamond"
        }
    }
}

private extension ExportReadinessSeverity {
    var title: String {
        switch self {
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }

    var sortPriority: Int {
        switch self {
        case .error:
            return 0
        case .warning:
            return 1
        case .info:
            return 2
        }
    }
}

private extension DocumentReferenceStatus {
    var title: String {
        switch self {
        case .valid:
            return "Valid"
        case .warning:
            return "Warning"
        case .skipped:
            return "Skipped"
        case .missing:
            return "Missing"
        case .malformed:
            return "Malformed"
        case .unsupported:
            return "Unsupported"
        case .blocked:
            return "Blocked"
        }
    }

    func tint(chrome: ResolvedAppChromeTheme) -> Color {
        switch self {
        case .valid:
            return chrome.accent
        case .warning, .missing, .malformed, .unsupported:
            return chrome.warning
        case .skipped, .blocked:
            return chrome.secondaryText
        }
    }
}
