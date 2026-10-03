import AppKit

@main
struct WindowSizingChecks {
    @MainActor static func main() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 660, height: 620),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        let view = ContentHeightWindowView()
        window.contentView = view
        func height() -> CGFloat { window.contentRect(forFrameRect: window.frame).height }
        func fit(_ value: CGFloat) {
            view.contentHeight = value
            view.updateWindowHeight()
        }

        fit(450)
        precondition(height() == 450 && window.contentMaxSize.height == 450)
        precondition(window.contentMinSize.height == 280)
        precondition(window.contentRect(forFrameRect: window.frame).width == 660)

        // Fitted windows follow incoming buckets and disappearing notices.
        fit(520)
        precondition(height() == 520 && window.contentMaxSize.height == 520)
        fit(430)
        precondition(height() == 430 && window.contentMaxSize.height == 430)

        // A user can shrink the viewport; refreshed content preserves that size.
        window.setContentSize(NSSize(width: 700, height: 300))
        fit(500)
        precondition(height() == 300 && window.contentMaxSize.height == 500)
        precondition(window.contentRect(forFrameRect: window.frame).width == 700)
        window.setContentSize(NSSize(width: 700, height: 100))
        fit(500)
        precondition(height() == 280, "A smaller viewport must be clamped to its minimum")
        fit(290)
        precondition(height() == 280 && window.contentMaxSize.height == 290)

        // Compact contents cannot produce contradictory min/max constraints.
        fit(240)
        precondition(height() == 240 && window.contentMinSize.height == 240)
        fit(.nan)
        precondition(height() == 240 && window.contentMaxSize.height == 240)

        // SwiftUI's hidden title bar uses a full-size content view under its
        // toolbar; that reserved area must be included to avoid a clipped footer.
        let toolbarWindow = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 660, height: 620),
                                     styleMask: [.titled, .resizable, .fullSizeContentView],
                                     backing: .buffered, defer: false)
        toolbarWindow.toolbar = NSToolbar(identifier: "WindowSizingChecks")
        let toolbarView = ContentHeightWindowView()
        toolbarWindow.contentView = toolbarView
        toolbarView.contentHeight = 450
        toolbarView.updateWindowHeight()
        precondition(toolbarWindow.contentLayoutRect.height == 450)
        let toolbarInset = toolbarWindow.contentRect(forFrameRect: toolbarWindow.frame).height - 450
        precondition(toolbarWindow.contentMinSize.height == 280 + toolbarInset)
        toolbarWindow.setContentSize(NSSize(width: 660, height: 100))
        toolbarView.updateWindowHeight()
        precondition(toolbarWindow.contentLayoutRect.height == 280,
                     "The toolbar must not consume part of the minimum viewport height")

        // SwiftUI can recompute native constraints during a resize. The view
        // must reapply the limit even when its measured content has not changed.
        toolbarWindow.contentMinSize.height = 0
        toolbarWindow.contentMaxSize.height = .greatestFiniteMagnitude
        toolbarWindow.setContentSize(NSSize(width: 660, height: 200))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        precondition(toolbarWindow.contentLayoutRect.height == 280)
        precondition(toolbarWindow.contentMinSize.height == 280 + toolbarInset)
        precondition(toolbarWindow.contentMaxSize.height == 450 + toolbarInset)

        print("PASS: content fit, minimum/maximum clamping, changing content, smaller viewport, independent width, compact/invalid measurements, toolbar insets, and restoring constraints after resize")
    }
}
