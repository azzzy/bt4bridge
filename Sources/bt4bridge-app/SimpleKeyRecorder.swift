import SwiftUI
import AppKit
import BT4BridgeCore

/// A simple key recorder that captures any single key press (including keys without modifiers)
@available(macOS 13.0, *)
struct SimpleKeyRecorder: View {
    let label: String
    @Binding var keyAction: KeyboardAction?
    @Binding var isActive: Bool
    @State private var recorderView: RecorderNSView?
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .trailing)
            
            Button(action: {
                isActive = true
                // Force focus on the recorder view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    recorderView?.window?.makeFirstResponder(recorderView)
                }
            }) {
                HStack {
                    if let action = keyAction {
                        Text(keyDescription(for: action))
                            .foregroundColor(isActive ? .blue : .primary)
                    } else {
                        Text("Not set")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(width: 200)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .background(
                RecorderView(
                    isActive: $isActive,
                    recorderView: $recorderView,
                    onKeyRecorded: { keyCode, modifiers in
                        keyAction = KeyboardAction(keyCodeValue: keyCode, modifiers: modifiers)
                        isActive = false
                    }
                )
                .frame(width: 1, height: 1)
            )
            
            if keyAction != nil {
                Button("×") {
                    keyAction = nil
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    private func keyDescription(for action: KeyboardAction) -> String {
        var parts: [String] = []
        
        if action.modifiers.contains(.control) {
            parts.append("⌃")
        }
        if action.modifiers.contains(.option) {
            parts.append("⌥")
        }
        if action.modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if action.modifiers.contains(.command) {
            parts.append("⌘")
        }
        
        // Get key name
        if let keyName = keyCodeToName(action.keyCode) {
            parts.append(keyName)
        } else {
            parts.append("Key \(action.keyCode)")
        }
        
        return parts.joined()
    }
    
    private func keyCodeToName(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 53: return "Escape"
        case 48: return "Tab"
        case 51: return "Delete"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        default: return nil
        }
    }
}

/// NSView that captures key events
private struct RecorderView: NSViewRepresentable {
    @Binding var isActive: Bool
    @Binding var recorderView: RecorderNSView?
    let onKeyRecorded: (UInt16, KeyModifiers) -> Void
    
    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onKeyRecorded = onKeyRecorded
        DispatchQueue.main.async {
            self.recorderView = view
        }
        return view
    }
    
    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        if isActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        } else {
            // Release focus when not active
            if nsView.window?.firstResponder == nsView {
                nsView.window?.makeFirstResponder(nil)
            }
        }
    }
}

private class RecorderNSView: NSView {
    var onKeyRecorded: ((UInt16, KeyModifiers) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard let onKeyRecorded = onKeyRecorded else { return }
        
        let keyCode = UInt16(event.keyCode)
        var modifiers = KeyModifiers()
        
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        
        onKeyRecorded(keyCode, modifiers)
    }
}
