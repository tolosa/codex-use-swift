import AppKit
import SwiftUI

/// A scroll view has no intrinsic maximum height, so constrain its window using
/// the measured height of the dashboard inside it instead.
struct WindowHeightLimit: NSViewRepresentable {
    let contentHeight: CGFloat

    func makeNSView(context: Context) -> ContentHeightWindowView {
        ContentHeightWindowView()
    }

    func updateNSView(_ view: ContentHeightWindowView, context: Context) {
        view.contentHeight = contentHeight
    }
}

final class ContentHeightWindowView: NSView {
    static let minimumViewportHeight: CGFloat = 280

    var contentHeight: CGFloat = 0 {
        didSet { scheduleUpdate() }
    }
    private var previousMaximum: CGFloat?
    private var updateScheduled = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willStartLiveResizeNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidResize),
                                                   name: NSWindow.didResizeNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillStartLiveResize),
                                                   name: NSWindow.willStartLiveResizeNotification, object: window)
        }
        previousMaximum = nil
        scheduleUpdate()
    }

    @objc private func windowDidResize(_ notification: Notification) {
        scheduleUpdate()
    }

    @objc private func windowWillStartLiveResize(_ notification: Notification) {
        updateWindowHeight()
    }

    private func scheduleUpdate() {
        guard !updateScheduled else { return }
        updateScheduled = true
        // Apply after SwiftUI has installed its own minimum-size constraints.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.updateWindowHeight()
        }
    }

    func updateWindowHeight() {
        guard let window, contentHeight.isFinite, contentHeight > 0 else { return }
        let contentRect = window.contentRect(forFrameRect: window.frame)
        // Hidden-title-bar windows extend their content view under the toolbar.
        // The dashboard lays out below that area, so include the toolbar inset
        // when converting its measured height into a window content size.
        let toolbarInset = max(0, contentRect.height - window.contentLayoutRect.height)
        let fittingHeight = ceil(contentHeight + toolbarInset)
        let screenHeight = window.screen.map {
            window.contentRect(forFrameRect: $0.visibleFrame).height
        } ?? fittingHeight
        let maximum = min(fittingHeight, screenHeight)
        let minimum = min(Self.minimumViewportHeight + toolbarInset, maximum)
        let currentHeight = contentRect.height
        let wasFittingContent = previousMaximum.map { abs(currentHeight - $0) < 1 } ?? true

        window.contentMinSize.height = minimum
        window.contentMaxSize.height = maximum
        previousMaximum = maximum

        // Follow content changes while fitted, but preserve a user's smaller
        // window. A disappearing notice or bucket must also lower the cap.
        let targetHeight = wasFittingContent ? maximum : min(max(currentHeight, minimum), maximum)
        guard abs(currentHeight - targetHeight) >= 1 else { return }
        var frame = window.frame
        let heightChange = targetHeight - currentHeight
        frame.size.height += heightChange
        frame.origin.y -= heightChange // Keep the top edge in place.
        if let screen = window.screen {
            frame.origin.y = max(screen.visibleFrame.minY, frame.origin.y)
        }
        window.setFrame(frame, display: true)
    }
}
