import SwiftUI
import OpenMarkedCore

struct PrintSettingsView: View {
    @EnvironmentObject private var appController: AppController
    @Environment(\.appChromeTheme) private var chrome

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Picker("Page Size", selection: configurationBinding(\.pageSize)) {
                    ForEach(PrintPageSize.allCases) { pageSize in
                        Text(pageSize.displayName).tag(pageSize)
                    }
                }

                Picker("Print Style", selection: configurationBinding(\.themeMode)) {
                    ForEach(PrintThemeMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Margins")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(chrome.secondaryText)

                HStack(spacing: 12) {
                    marginStepper("Top", \.top)
                    marginStepper("Right", \.right)
                }
                HStack(spacing: 12) {
                    marginStepper("Bottom", \.bottom)
                    marginStepper("Left", \.left)
                }
            }

            HStack(spacing: 12) {
                Toggle("Limit width", isOn: contentWidthEnabledBinding)

                Stepper(
                    "Width",
                    value: contentWidthBinding,
                    in: PrintConfiguration.minimumContentMaxWidth...PrintConfiguration.maximumContentMaxWidth,
                    step: 20
                )
                .disabled(appController.settings.printConfiguration.contentMaxWidth == nil)

                Text("\(appController.settings.printConfiguration.contentMaxWidth ?? PrintConfiguration.defaultContentMaxWidth) px")
                    .monospacedDigit()
                    .frame(width: 72, alignment: .trailing)
                    .foregroundStyle(chrome.secondaryText)
            }

            HStack(spacing: 14) {
                Toggle("Document title", isOn: configurationBinding(\.includesDocumentTitle))
                Toggle("New page at H1", isOn: configurationBinding(\.startsHeadingOneOnNewPage))
                Toggle("New page at H2", isOn: configurationBinding(\.startsHeadingTwoOnNewPage))
            }
        }
    }

    private func marginStepper(_ title: String, _ keyPath: WritableKeyPath<PrintMargins, Double>) -> some View {
        HStack(spacing: 6) {
            Stepper(title, value: marginBinding(keyPath), in: PrintMargins.minimumInches...PrintMargins.maximumInches, step: 0.05)
            Text(String(format: "%.2f in", appController.settings.printConfiguration.margins[keyPath: keyPath]))
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)
                .foregroundStyle(chrome.secondaryText)
        }
    }

    private func configurationBinding<Value>(_ keyPath: WritableKeyPath<PrintConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { appController.settings.printConfiguration[keyPath: keyPath] },
            set: { newValue in
                appController.updateSettings { settings in
                    settings.printConfiguration[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func marginBinding(_ keyPath: WritableKeyPath<PrintMargins, Double>) -> Binding<Double> {
        Binding(
            get: { appController.settings.printConfiguration.margins[keyPath: keyPath] },
            set: { newValue in
                appController.updateSettings { settings in
                    settings.printConfiguration.margins[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var contentWidthEnabledBinding: Binding<Bool> {
        Binding(
            get: { appController.settings.printConfiguration.contentMaxWidth != nil },
            set: { isEnabled in
                appController.updateSettings { settings in
                    settings.printConfiguration.contentMaxWidth = isEnabled ? PrintConfiguration.defaultContentMaxWidth : nil
                }
            }
        )
    }

    private var contentWidthBinding: Binding<Int> {
        Binding(
            get: { appController.settings.printConfiguration.contentMaxWidth ?? PrintConfiguration.defaultContentMaxWidth },
            set: { newValue in
                appController.updateSettings { settings in
                    settings.printConfiguration.contentMaxWidth = newValue
                }
            }
        )
    }
}
