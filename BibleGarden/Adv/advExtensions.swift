import SwiftUI

// MARK: - iOS 15 Compatibility

enum AppHeaderMetrics {
    static let controlSize: CGFloat = 32
    static let bottomPadding: CGFloat = 6
    static let embeddedTopInset: CGFloat = 8
    static let embeddedBottomInset: CGFloat = 2
    static let embeddedCornerRadius: CGFloat = 18
}

func appWindowTopInset() -> CGFloat {
    (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
        .windows.first?.safeAreaInsets.top ?? 0
}

func appHeaderTopPadding(for topInset: CGFloat, extraTop: CGFloat = 0, extraTopSmall: CGFloat = 0) -> CGFloat {
    let basePadding: CGFloat = topInset > 40 ? 0 : 10
    let extra: CGFloat = topInset > 40 ? extraTop : extraTopSmall
    return basePadding + extra
}

extension View {
    @ViewBuilder
    func sheetFullScreen() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    /// Adaptive header padding: adds top padding only when safe area is small (iPad, iPhone SE),
    /// always adds bottom padding for consistent spacing below the header.
    /// - Parameters:
    ///   - extraTop: additional top padding for large-safe-area devices (iPhone with notch), default 0
    ///   - extraTopSmall: additional top padding for small-safe-area devices (iPad, iPhone SE), default 0
    func headerPadding(extraTop: CGFloat = 0, extraTopSmall: CGFloat = 0) -> some View {
        return self
            .padding(.top, appHeaderTopPadding(for: appWindowTopInset(), extraTop: extraTop, extraTopSmall: extraTopSmall))
            .padding(.bottom, AppHeaderMetrics.bottomPadding)
    }

    @ViewBuilder
    func hideScrollContentBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func appHeaderBackground(isEmbedded: Bool = false, cornerRadius: CGFloat = AppHeaderMetrics.embeddedCornerRadius) -> some View {
        if isEmbedded {
            self
                .padding(.top, AppHeaderMetrics.embeddedTopInset)
                .padding(.bottom, AppHeaderMetrics.embeddedBottomInset)
                .background(Color("DarkGreen").brightness(0.05))
                .clipShape(TopRoundedRectangle(radius: cornerRadius))
        } else {
            self
                .background(Color("DarkGreen").brightness(0.05))
        }
    }
}

/// Rounded rectangle with rounding only on the top (iOS 15 replacement for UnevenRoundedRectangle)
struct TopRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                     radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                     radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Rounded rectangle with rounding only on the left side (iOS 15 replacement for UnevenRoundedRectangle)
struct LeftRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                     radius: radius, startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                     radius: radius, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
