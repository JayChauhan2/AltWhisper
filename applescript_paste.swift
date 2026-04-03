import Foundation

let script = """
tell application "System Events"
    keystroke "v" using command down
end tell
"""

var error: NSDictionary?
if let appleScript = NSAppleScript(source: script) {
    appleScript.executeAndReturnError(&error)
    if let error = error {
        print("AppleScript failed: \(error)")
    } else {
        print("AppleScript succeeded!")
    }
}
