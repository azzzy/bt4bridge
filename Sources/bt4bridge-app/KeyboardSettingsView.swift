import SwiftUI
import BT4BridgeCore

@available(macOS 13.0, *)
struct KeyboardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var button1Key: KeyboardAction? = KeyboardAction(keyCode: .space)
    @State private var button2Key: KeyboardAction? = KeyboardAction(keyCode: .rightArrow)
    @State private var button3Key: KeyboardAction? = KeyboardAction(keyCode: .upArrow)
    @State private var button4Key: KeyboardAction? = KeyboardAction(keyCode: .downArrow)
    @State private var activeRecorder: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            
            Text("Click a field and press any key to record:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                SimpleKeyRecorder(label: "Button 1:", keyAction: $button1Key, isActive: Binding(
                    get: { activeRecorder == 1 },
                    set: { if $0 { activeRecorder = 1 } else if activeRecorder == 1 { activeRecorder = nil } }
                ))
                SimpleKeyRecorder(label: "Button 2:", keyAction: $button2Key, isActive: Binding(
                    get: { activeRecorder == 2 },
                    set: { if $0 { activeRecorder = 2 } else if activeRecorder == 2 { activeRecorder = nil } }
                ))
                SimpleKeyRecorder(label: "Button 3:", keyAction: $button3Key, isActive: Binding(
                    get: { activeRecorder == 3 },
                    set: { if $0 { activeRecorder = 3 } else if activeRecorder == 3 { activeRecorder = nil } }
                ))
                SimpleKeyRecorder(label: "Button 4:", keyAction: $button4Key, isActive: Binding(
                    get: { activeRecorder == 4 },
                    set: { if $0 { activeRecorder = 4 } else if activeRecorder == 4 { activeRecorder = nil } }
                ))
            }
            .padding(.vertical, 8)
            
            Divider()
            
            HStack {
                Button("Reset to Defaults") {
                    button1Key = KeyboardAction(keyCode: .space)
                    button2Key = KeyboardAction(keyCode: .rightArrow)
                    button3Key = KeyboardAction(keyCode: .upArrow)
                    button4Key = KeyboardAction(keyCode: .downArrow)
                }
                
                Spacer()
                
                Button("Done") {
                    saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450, height: 350)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        Task {
            button1Key = await Bridge.sharedConfiguration.getKeyboardAction(for: 1)
            button2Key = await Bridge.sharedConfiguration.getKeyboardAction(for: 2)
            button3Key = await Bridge.sharedConfiguration.getKeyboardAction(for: 3)
            button4Key = await Bridge.sharedConfiguration.getKeyboardAction(for: 4)
        }
    }
    
    private func saveSettings() {
        Task {
            if let key = button1Key {
                await Bridge.sharedConfiguration.setKeyboardAction(for: 1, action: key)
            }
            if let key = button2Key {
                await Bridge.sharedConfiguration.setKeyboardAction(for: 2, action: key)
            }
            if let key = button3Key {
                await Bridge.sharedConfiguration.setKeyboardAction(for: 3, action: key)
            }
            if let key = button4Key {
                await Bridge.sharedConfiguration.setKeyboardAction(for: 4, action: key)
            }
        }
    }
}

@available(macOS 13.0, *)
#Preview {
    KeyboardSettingsView()
}
