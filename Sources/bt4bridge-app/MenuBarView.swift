import SwiftUI
import BT4BridgeCore

@available(macOS 13.0, *)
struct MenuBarView: View {
    
    @EnvironmentObject private var bridgeModel: BridgeModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Connection status
            StatusLine()
            
            // MIDI status
            MIDIStatusLine()
            
            // LED Indicators (all 4 on one line)
            LEDStatusLine()
            
            Divider()
            
            // Actions
            if bridgeModel.connectionStatus == .connected {
                Button("Disconnect") {
                    Task { 
                        await bridgeModel.stop()
                    }
                }
            } else if bridgeModel.connectionStatus == .disconnected {
                Button("Connect") {
                    Task { 
                        try? await bridgeModel.start()
                    }
                }
            } else {
                // Scanning state - show disabled reconnect
                Button("Scanning...") { }
                    .disabled(true)
            }
            
            Divider()
            
            // System Section
            SystemSection()
        }
    }
}

// MARK: - Status Lines

@available(macOS 13.0, *)
struct StatusLine: View {
    
    @EnvironmentObject private var bridgeModel: BridgeModel
    
    var body: some View {
        Text(statusText)
    }
    
    private var statusText: AttributedString {
        var result = AttributedString(connectionText)
        result.foregroundColor = connectionColor
        
        if let rssi = bridgeModel.rssi {
            result += AttributedString("  (\(rssi) dBm)")
        }
        return result
    }
    
    private var connectionColor: Color {
        switch bridgeModel.connectionStatus {
        case .disconnected: return Color(white: 0.5)
        case .scanning: return Color(white: 0.5)
        case .connected: return .primary
        }
    }
    
    private var connectionText: String {
        switch bridgeModel.connectionStatus {
        case .disconnected: return "Disconnected"
        case .scanning: return "Scanning..."
        case .connected: return "Connected"
        }
    }
}

@available(macOS 13.0, *)
struct MIDIStatusLine: View {
    
    @EnvironmentObject private var bridgeModel: BridgeModel
    
    var body: some View {
        Text(midiText)
    }
    
    private var midiText: AttributedString {
        var result = AttributedString("MIDI: ")
        var status = AttributedString(bridgeModel.midiPortsActive ? "Active" : "Inactive")
        status.foregroundColor = bridgeModel.midiPortsActive ? .primary : Color(white: 0.5)
        result += status
        return result
    }
}

// MARK: - LED Section

@available(macOS 13.0, *)
struct LEDStatusLine: View {
    
    @EnvironmentObject private var bridgeModel: BridgeModel
    
    var body: some View {
        Text(ledText)
    }
    
    private var ledText: AttributedString {
        var result = AttributedString("LEDs: ")
        
        for ledNumber in 1...4 {
            let isOn = bridgeModel.ledStates[ledNumber] ?? false
            var indicator = AttributedString(isOn ? "●" : "○")
            // Use primary color (bright) for ON, gray for OFF
            indicator.foregroundColor = isOn ? .primary : Color(white: 0.5)
            result += indicator
            if ledNumber < 4 {
                result += AttributedString(" ")
            }
        }
        
        return result
    }
}

// MARK: - System Section

@available(macOS 13.0, *)
struct SystemSection: View {
    
    var body: some View {
        Group {
            Button("About") {
                showAbout()
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
    
    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "PG_BT4 Bridge"
        alert.informativeText = "Version 1.0.0\n\nBluetooth MIDI bridge for PG_BT4 device.\n\nCopyright © 2024"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Preview

@available(macOS 13.0, *)
#Preview {
    MenuBarView()
        .environmentObject(BridgeModel())
}
