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

            RoundedRectangle(cornerRadius: side * 0.103, style: .continuous)
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
                .frame(width: side * 0.607, height: side * 0.653)
                .position(x: side * 0.475, y: side * 0.503)
                .shadow(color: .black.opacity(0.22), radius: side * 0.035, x: 0, y: side * 0.027)

            OpenMarkedLogoFoldShape()
                .fill(Color(red: 0.780, green: 0.976, blue: 0.937))
                .frame(width: side, height: side)

            OpenMarkedLogoFoldStrokeShape()
                .stroke(Color(red: 0.553, green: 0.871, blue: 0.816), style: StrokeStyle(lineWidth: side * 0.018, lineJoin: .round))
                .frame(width: side, height: side)

            Capsule()
                .fill(Color(red: 0.059, green: 0.463, blue: 0.431))
                .frame(width: side * 0.232, height: side * 0.041)
                .position(x: side * 0.423, y: side * 0.311)

            OpenMarkedLogoMShape()
                .stroke(
                    Color(red: 0.059, green: 0.463, blue: 0.431),
                    style: StrokeStyle(lineWidth: side * 0.068, lineCap: .round, lineJoin: .round)
                )
                .frame(width: side, height: side)

            OpenMarkedLogoArrowShape()
                .fill(Color(red: 0.145, green: 0.388, blue: 0.922))
                .frame(width: side, height: side)
        }
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

private struct OpenMarkedLogoFoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaledPath(in: rect) { path, point in
            path.move(to: point(670, 180))
            path.addLine(to: point(796, 306))
            path.addLine(to: point(796, 356))
            path.addLine(to: point(758, 356))
            path.addQuadCurve(to: point(670, 268), control: point(670, 356))
            path.closeSubpath()
        }
    }
}

private struct OpenMarkedLogoFoldStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaledPath(in: rect) { path, point in
            path.move(to: point(670, 180))
            path.addLine(to: point(670, 268))
            path.addQuadCurve(to: point(758, 356), control: point(670, 356))
            path.addLine(to: point(796, 356))
        }
    }
}

private struct OpenMarkedLogoMShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaledPath(in: rect) { path, point in
            path.move(to: point(308, 624))
            path.addLine(to: point(308, 408))
            path.addLine(to: point(382, 408))
            path.addLine(to: point(512, 558))
            path.addLine(to: point(642, 408))
            path.addLine(to: point(716, 408))
            path.addLine(to: point(716, 624))
        }
    }
}

private struct OpenMarkedLogoArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        scaledPath(in: rect) { path, point in
            path.move(to: point(512, 702))
            path.addLine(to: point(410, 600))
            path.addLine(to: point(478, 600))
            path.addLine(to: point(478, 424))
            path.addLine(to: point(546, 424))
            path.addLine(to: point(546, 600))
            path.addLine(to: point(614, 600))
            path.closeSubpath()
        }
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
