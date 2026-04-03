import Foundation
import ApplicationServices

let source = CGEventSource(stateID: .hidSystemState)
let vKeyCode: CGKeyCode = 0x09
guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
    print("could not create keydown")
    exit(1)
}
guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
    print("could not create keyup")
    exit(1)
}

keyDown.flags = .maskCommand
keyUp.flags = .maskCommand
keyDown.post(tap: .cghidEventTap)
keyUp.post(tap: .cghidEventTap)
print("Pasted!")
