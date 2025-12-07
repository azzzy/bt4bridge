import SwiftUI
import BT4BridgeCore

@available(macOS 13.0, *)
@main
struct PG_BT4BridgeApp: App {
    
    @StateObject private var bridgeModel = BridgeModel()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(bridgeModel)
                .task {
                    // Start bridge when menu bar is ready
                    do {
                        try await bridgeModel.start()
                    } catch {
                        print("Failed to start bridge: \(error)")
                    }
                }
        } label: {
            if let image = customIcon {
                Image(nsImage: image)
            } else {
                Image(systemName: "headphones.circle")
            }
        }
        .menuBarExtraStyle(.menu)
    }
    
    /// Load custom SVG icon
    private var customIcon: NSImage? {
        // Try to load from bundle
        guard let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("bt4bridge_bt4bridge-app.bundle"),
              let bundle = Bundle(url: bundleURL),
              let svgURL = bundle.url(forResource: "MenuBarIcon", withExtension: "svg"),
              let svgData = try? Data(contentsOf: svgURL),
              let image = NSImage(data: svgData) else {
            print("⚠️ Failed to load custom icon, using system icon")
            return nil
        }
        
        // Set template rendering mode so it uses the menu bar color
        image.isTemplate = true
        print("✅ Loaded custom SVG icon")
        return image
    }
}
