import Foundation
import ApplicationServices

DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
    let source = CGEventSource(stateID: .hidSystemState)
    let vKeyCode: CGKeyCode = 0x09
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)!
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)!
    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
    print("Pasted!")
    exit(0)
}
RunLoop.main.run()
