import AppKit
import SwiftUI

extension View {
    /// Sizes a new window to a 1.44 aspect ratio at 53% of its screen's height, centered.
    /// After that the window is left alone.
    func defaultWindowFrame() -> some View {
        background(DefaultWindowFrame())
    }
}

private struct DefaultWindowFrame: NSViewRepresentable {
    func makeNSView(context: Context) -> FrameSettingView { FrameSettingView() }
    func updateNSView(_ nsView: FrameSettingView, context: Context) {}
}

private final class FrameSettingView: NSView {
    /// 1263 × 877 on a 3008 × 1662 screen, scaled to whichever screen the window opens on.
    private static let referenceWindow = CGSize(width: 1263, height: 877)
    private static let referenceScreen = CGSize(width: 3008, height: 1662)

    private var didApply = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didApply, let window, let screen = window.screen?.visibleFrame else { return }
        didApply = true

        // Same share of the screen's height on every display; shrink both sides if too wide.
        let heightScale = screen.height / Self.referenceScreen.height
        let scale = heightScale * min(1, screen.width / (Self.referenceWindow.width * heightScale))
        let size = CGSize(
            width: (Self.referenceWindow.width * scale).rounded(),
            height: (Self.referenceWindow.height * scale).rounded()
        )
        window.setFrame(NSRect(
            x: (screen.midX - size.width / 2).rounded(),
            y: (screen.midY - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        ), display: true)
    }
}
