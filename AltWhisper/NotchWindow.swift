import SwiftUI
import AppKit

class NotchWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false // Remove window shadow to prevent "weird background" look
        self.level = .statusBar
        self.ignoresMouseEvents = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Center at the top, slightly offset down for visibility
        if let mainScreen = NSScreen.main {
            let screenFrame = mainScreen.frame
            let windowFrame = NSRect(
                x: (screenFrame.width - contentRect.width) / 2,
                y: screenFrame.height - contentRect.height - 20, // Move 10pts down from the top edge
                width: contentRect.width,
                height: contentRect.height
            )
            self.setFrame(windowFrame, display: true)
        }
    }
}

struct NotchView: View {
    @ObservedObject var manager: KeyboardManager

    var body: some View {
        VStack(spacing: 0) {
            if manager.isFnPressed {
                HStack(spacing: 4) {
                    ForEach(0..<12) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 4, height: barHeight(for: i))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black)
                .cornerRadius(12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.isFnPressed)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Create a symmetric waveform look
        let baseHeight: CGFloat = 4
        let multiplier = CGFloat.random(in: 0.8...1.2) // Add some jitter
        let level = CGFloat(manager.audioManager.audioLevel)
        
        let center = 5.5
        let dist = abs(Double(index) - center)
        let factor = max(0.2, (6.0 - dist) / 6.0)
        
        return baseHeight + (level * 30 * factor * multiplier)
    }
}
