import AppKit
import SwiftUI
import OpenMarkedCore

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
            LinksInspectorSection(report: report)
        case .assets:
            AssetsInspectorSection(report: report)
        case .diagnostics:
            DiagnosticsInspectorSection(report: report)
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

    var body: some View {
        InspectorSectionStack(title: "Links") {
            if report.links.isEmpty {
                InlineEmptyState(systemImage: "link", message: "No rendered links.")
            } else {
                ForEach(report.links) { link in
                    InspectorReferenceRow(
                        title: link.text.isEmpty ? link.target : link.text,
                        subtitle: link.target,
                        systemImage: link.kind.systemImage,
                        status: link.status,
                        diagnosticsCount: link.diagnostics.count
                    )
                }
            }
        }
    }
}

private struct AssetsInspectorSection: View {
    let report: DocumentInspectionReport

    var body: some View {
        InspectorSectionStack(title: "Assets") {
            if report.assets.isEmpty {
                InlineEmptyState(systemImage: "photo", message: "No rendered images.")
            } else {
                ForEach(report.assets) { asset in
                    InspectorReferenceRow(
                        title: asset.altText.isEmpty ? asset.kind.title : asset.altText,
                        subtitle: asset.source,
                        systemImage: asset.kind.systemImage,
                        status: asset.status,
                        diagnosticsCount: asset.diagnostics.count
                    )
                }
            }
        }
    }
}

private struct DiagnosticsInspectorSection: View {
    let report: DocumentInspectionReport

    var body: some View {
        InspectorSectionStack(title: "Diagnostics") {
            if report.diagnostics.isEmpty {
                InlineEmptyState(systemImage: "checkmark.circle", message: "No diagnostics.")
            } else {
                ForEach(report.diagnostics) { diagnostic in
                    InspectorDiagnosticRow(diagnostic: diagnostic)
                }
            }
        }
    }
}

private struct StatisticsInspectorSection: View {
    let report: DocumentInspectionReport

    var body: some View {
        InspectorSectionStack(title: "Statistics") {
            InspectorMetricGrid(
                metrics: [
                    InspectorMetric(title: "Words", value: "\(report.statistics.words)", systemImage: "text.alignleft"),
                    InspectorMetric(title: "Characters", value: "\(report.statistics.characters)", systemImage: "character.cursor.ibeam"),
                    InspectorMetric(title: "Lines", value: "\(report.statistics.lines)", systemImage: "text.justify.left"),
                    InspectorMetric(title: "Read Time", value: "\(report.statistics.readingTimeMinutes)m", systemImage: "clock"),
                    InspectorMetric(title: "Tables", value: "\(report.statistics.tableCount)", systemImage: "tablecells"),
                    InspectorMetric(title: "Code", value: "\(report.statistics.codeBlockCount)", systemImage: "chevron.left.forwardslash.chevron.right"),
                    InspectorMetric(title: "Callouts", value: "\(report.statistics.calloutCount)", systemImage: "quote.bubble"),
                    InspectorMetric(title: "Mermaid", value: "\(report.statistics.mermaidDiagramCount)", systemImage: "point.3.connected.trianglepath.dotted"),
                    InspectorMetric(title: "Math", value: "\(report.statistics.mathExpressionCount)", systemImage: "function"),
                    InspectorMetric(title: "Warnings", value: "\(report.statistics.missingReferenceCount)", systemImage: "exclamationmark.triangle")
                ]
            )

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
        }
    }
}

private struct ExportInspectorSection: View {
    let report: DocumentInspectionReport

    var body: some View {
        InspectorSectionStack(title: "Export") {
            InspectorReferenceRow(
                title: report.exportReadiness.isReady ? "Ready" : "Needs Review",
                subtitle: report.exportReadiness.issues.isEmpty ? "No readiness issues." : "\(report.exportReadiness.issues.count) readiness issue\(report.exportReadiness.issues.count == 1 ? "" : "s").",
                systemImage: report.exportReadiness.isReady ? "checkmark.circle" : "exclamationmark.triangle",
                status: report.exportReadiness.isReady ? .valid : .warning,
                diagnosticsCount: 0
            )

            if report.exportReadiness.issues.isEmpty {
                InlineEmptyState(systemImage: "square.and.arrow.up", message: "No export readiness issues.")
            } else {
                ForEach(report.exportReadiness.issues) { issue in
                    InspectorIssueRow(issue: issue)
                }
            }
        }
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
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String
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

            VStack(spacing: 0) {
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
                    InspectorBadge(title: status.title, tint: status.tint(chrome: chrome))
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(chrome.secondaryText)
                    .lineLimit(2)
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

    var body: some View {
        InspectorReferenceRow(
            title: diagnostic.kind.rawValue,
            subtitle: diagnostic.source.map { "\(diagnostic.message) (\($0))" } ?? diagnostic.message,
            systemImage: diagnostic.severity == .warning ? "exclamationmark.triangle" : "info.circle",
            status: diagnostic.severity == .warning ? .warning : .skipped,
            diagnosticsCount: 0
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
            diagnosticsCount: 0
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
