import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!
    private var popoverController: PopoverController!
    private var usageMonitor: ClaudeUsageMonitor!
    private var scheduledTaskManager: ScheduledTaskManager!
    private var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app as UIElement (hide from Dock)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize core components
        usageMonitor = ClaudeUsageMonitor()
        scheduledTaskManager = ScheduledTaskManager()
        
        // Initialize menu bar controller first
        menuBarController = MenuBarController(monitor: usageMonitor) { [weak self] in
            self?.popoverController.togglePopover()
        }
        
        // Initialize popover controller with status button
        popoverController = PopoverController(
            contentView: ContentView()
                .environmentObject(usageMonitor)
                .environmentObject(scheduledTaskManager),
            statusButton: menuBarController.statusItem.button!
        )
        
        // Set timer (6 second interval)
        timer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            self?.scheduleUpdate()
        }
        
        // Update initial usage
        scheduleUpdate()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        menuBarController?.cleanup()
        popoverController?.cleanup()
    }
    
    @MainActor
    private func updateUsage() async {
        await usageMonitor.updateUsage()
        menuBarController.updateDisplay()
    }
    
    private func scheduleUpdate() {
        Task { await updateUsage() }
    } 
}