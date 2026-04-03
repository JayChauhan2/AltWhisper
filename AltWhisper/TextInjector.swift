import Foundation
import ApplicationServices
import AppKit

/// Handles detecting focused text fields and injecting transcribed text via simulated paste.
class TextInjector {
    
    /// Checks whether the currently focused UI element is a text input.
    /// Uses two strategies: (1) check if AXValue is settable (most reliable), (2) fall back to role-based check.
    func isTextFieldFocused() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success, let element = focusedElement else {
            print("🔍 Could not get focused element (AX result: \(result.rawValue))")
            return false
        }
        
        let axElement = element as! AXUIElement
        
        // Debug: log the role and subrole of the focused element
        var role: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role)
        var subrole: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXSubroleAttribute as CFString, &subrole)
        print("🔍 Focused element — role: \(role as? String ?? "nil"), subrole: \(subrole as? String ?? "nil")")
        
        // Strategy 1: Check if the AXValue attribute is settable (most reliable)
        // Any element that accepts text input will have a settable AXValue.
        var isSettable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(axElement, kAXValueAttribute as CFString, &isSettable)
        if settableResult == .success && isSettable.boolValue {
            print("🔍 AXValue is settable → text field detected")
            return true
        }
        
        // Strategy 2: Fall back to role-based check
        if let roleString = role as? String {
            let textRoles: Set<String> = [
                kAXTextFieldRole,
                kAXTextAreaRole,
                "AXComboBox",
                "AXSearchField",
                "AXWebArea",
            ]
            if textRoles.contains(roleString) {
                print("🔍 Role match → text field detected")
                return true
            }
        }
        
        print("🔍 Not a text field (settable result: \(settableResult.rawValue), isSettable: \(isSettable.boolValue))")
        return false
    }
    
    /// Injects the given text into the target application by re-focusing it and simulating Cmd+V.
    func injectText(_ text: String, into targetApp: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        
        // Save the current clipboard string (if any)
        let savedString = pasteboard.string(forType: .string)
        
        // Set the transcribed text onto the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Re-activate the original app so Cmd+V lands there, not on AltWhisper
        if let app = targetApp {
            app.activate(options: .activateIgnoringOtherApps)
        }
        
        // Small delay to let the app finish activating before we post the keystroke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
            
            // Restore the clipboard after another short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                pasteboard.clearContents()
                if let saved = savedString {
                    pasteboard.setString(saved, forType: .string)
                }
            }
        }
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let commandKey: CGKeyCode = 0x37  // Command
        let vKeyCode: CGKeyCode = 0x09    // V
        
        // Create events for Cmd down, V down, V up, Cmd up
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: commandKey, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: commandKey, keyDown: false)
        
        // Set the command flag on the V events
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        // Post events in the correct sequence
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
