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
                HStack(spacing: 6) {
                    ForEach(0..<6) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary)
                            .frame(width: 4, height: barHeight(for: i))
                    }
                }
                .frame(width: 100, height: 44)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.isFnPressed)
        .animation(.easeOut(duration: 0.08), value: manager.audioLevel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 5
        let level = CGFloat(manager.audioLevel)
        
        // Boost the level significantly to make it more noticeable
        let boostedLevel = pow(level, 0.5)
        
        // Symmetrical heights for the 6 bars
        let heights: [CGFloat] = [0.4, 0.7, 1.0, 1.0, 0.7, 0.4]
        let factor = heights[index]
        
        return baseHeight + (boostedLevel * 35 * factor)
    }
}
