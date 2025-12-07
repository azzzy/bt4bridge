import AppKit
import SwiftUI

@available(macOS 13.0, *)
class KeyboardSettingsWindowManager {
    static let shared = KeyboardSettingsWindowManager()
    
    private var settingsWindow: NSWindow?
    private var windowDelegate: WindowDelegate?
    
    private init() {}
    
    func showSettings() {
        // If window already exists, just bring it to front
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create new window
        let settingsView = KeyboardSettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Keyboard Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 350))
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false
        
        // Set delegate to track window closing
        let delegate = WindowDelegate { [weak self] in
            self?.settingsWindow = nil
            self?.windowDelegate = nil
        }
        window.delegate = delegate
        
        self.settingsWindow = window
        self.windowDelegate = delegate
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Helper class to track window closing
private class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
