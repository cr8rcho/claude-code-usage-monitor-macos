import AppKit
import SwiftUI

// Manages popover display using borderless window
class PopoverController: NSObject {
    private var window: NSWindow?
    private var eventMonitor: EventMonitor?
    private weak var statusButton: NSStatusBarButton?
    
    init(contentView: some View, statusButton: NSStatusBarButton) {
        self.statusButton = statusButton
        
        super.init()
        
        // Create borderless window for flush positioning
        // Wrap contentView with visual effect and padding for transparency and corner radius
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow // Semi-transparent material
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 535),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        // Set up visual effect view as content view
        window?.contentView = visualEffectView
        visualEffectView.addSubview(hostingController.view)
        hostingController.view.frame = visualEffectView.bounds
        hostingController.view.autoresizingMask = [.width, .height]
        
        window?.level = .statusBar
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window?.isMovableByWindowBackground = false
        window?.backgroundColor = NSColor.clear
        window?.isOpaque = false
        window?.isReleasedWhenClosed = false
        window?.hasShadow = true
        
        setupEventMonitor()
    }
    
    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, let window = self.window, window.isVisible {
                self.close()
            }
        }
    }
    
    func togglePopover() {
        if window?.isVisible == true {
            close()
        } else {
            show()
        }
    }
    
    private func show() {
        guard let button = statusButton,
              let buttonWindow = button.window,
              let window = window else { return }
        
        // Get button frame in screen coordinates
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        
        // Position window directly below button with 5px gap
        let x = buttonFrame.midX - window.frame.width / 2
        let y = buttonFrame.minY - window.frame.height - 5 // 5px gap from menu bar
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        
        eventMonitor?.start()
    }
    
    private func close() {
        window?.orderOut(nil)
        eventMonitor?.stop()
    }
    
    func cleanup() {
        eventMonitor?.stop()
        window?.close()
    }
}