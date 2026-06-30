import AppKit
import SwiftUI

struct OpenMarkedLogoView: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            logo(side: side)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func logo(side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.205, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.059, green: 0.090, blue: 0.165),
                            Color(red: 0.059, green: 0.463, blue: 0.431),
                            Color(red: 0.145, green: 0.388, blue: 0.922)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            OpenMarkedLogoDocumentShape()
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            Color(red: 0.918, green: 0.969, blue: 0.957)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: side, height: side)
                .shadow(color: .black.opacity(0.22), radius: side * 0.035, x: 0, y: side * 0.027)

            OpenMarkedLogoFoldShape()
                .fill(Color(red: 0.784, green: 0.969, blue: 0.933))
                .frame(width: side, height: side)

            OpenMarkedLogoFoldStrokeShape()
                .stroke(Color(red: 0.510, green: 0.847, blue: 0.792), style: StrokeStyle(lineWidth: side * 0.018, lineJoin: .round))
                .frame(width: side, height: side)

            contentLine(width: 276, centerY: 336)
                .fill(Color(red: 0.059, green: 0.463, blue: 0.431))
                .frame(width: side, height: side)

            contentLine(width: 220, centerY: 400)
                .fill(Color(red: 0.369, green: 0.918, blue: 0.831))
                .frame(width: side, height: side)

            OpenMarkedLogoMShape()
                .stroke(
                    Color(red: 0.059, green: 0.463, blue: 0.431),
                    style: StrokeStyle(lineWidth: side * 0.063, lineCap: .round, lineJoin: .round)
                )
                .frame(width: side, height: side)
        }
    }

    private func contentLine(width: CGFloat, centerY: CGFloat) -> some Shape {
        ScaledRoundedRect(
            x: 304,
            y: centerY - 18,
            width: width,
            height: 36,
            cornerRadius: 18
        )
    }
}

enum OpenMarkedAppIcon {
    static func image() -> NSImage? {
        if let image = NSImage(named: "OpenMarkedIcon") {
            return image
        }

        guard let iconURL = Bundle.main.url(forResource: "OpenMarkedIcon", withExtension: "icns") else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
    }
}

private struct OpenMarkedLogoDocumentShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaledPath(in: rect) { path, point in
            path.move(to: point(288, 176))
            path.addLine(to: point(660, 176))
            path.addLine(to: point(800, 316))
            path.addLine(to: point(800, 736))
            path.addQuadCurve(to: point(688, 848), control: point(800, 848))
            path.addLine(to: point(288, 848))
            path.addQuadCurve(to: point(176, 736), control: point(176, 848))
            path.addLine(to: point(176, 288))
            path.addQuadCurve(to: point(288, 176), control: point(176, 176))
            path.closeSubpath()
        }
    }
}

private struct OpenMarkedLogoFoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaledPath(in: rect) { path, point in
            path.move(to: point(660, 176))
            path.addLine(to: point(800, 316))
            path.addLine(to: point(690, 316))
            path.addQuadCurve(to: point(660, 286), control: point(660, 316))
            path.closeSubpath()
        }
    }
}

private struct OpenMarkedLogoFoldStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaledPath(in: rect) { path, point in
            path.move(to: point(660, 176))
            path.addLine(to: point(660, 286))
            path.addQuadCurve(to: point(690, 316), control: point(660, 316))
            path.addLine(to: point(800, 316))
        }
    }
}

private struct OpenMarkedLogoMShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaledPath(in: rect) { path, point in
            path.move(to: point(304, 656))
            path.addLine(to: point(304, 480))
            path.addLine(to: point(370, 480))
            path.addLine(to: point(512, 642))
            path.addLine(to: point(654, 480))
            path.addLine(to: point(720, 480))
            path.addLine(to: point(720, 656))
        }
    }
}

private struct ScaledRoundedRect: Shape {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 1024
        let offsetX = rect.midX - (1024 * scale / 2)
        let offsetY = rect.midY - (1024 * scale / 2)
        let scaledRect = CGRect(
            x: offsetX + x * scale,
            y: offsetY + y * scale,
            width: width * scale,
            height: height * scale
        )
        return Path(roundedRect: scaledRect, cornerRadius: cornerRadius * scale)
    }
}

private func scaledPath(in rect: CGRect, build: (inout Path, (CGFloat, CGFloat) -> CGPoint) -> Void) -> Path {
    var path = Path()
    let scale = min(rect.width, rect.height) / 1024
    let offsetX = rect.midX - (1024 * scale / 2)
    let offsetY = rect.midY - (1024 * scale / 2)
    let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
        CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
    }
    build(&path, point)
    return path
}
