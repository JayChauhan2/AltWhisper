//
//  AltWhisperApp.swift
//  AltWhisper
//
//  Created by Jay Chauhan on 4/3/26.
//

import SwiftUI
import AppKit
import Combine

class KeyboardManager: NSObject, ObservableObject {
    @Published var isFnPressed = false
    @Published var isAccessibilityTrusted = AXIsProcessTrusted()
    @ObservedObject var audioManager = AudioManager()
    private var timer: Timer?
    private var notchWindow: NotchWindow?

    func setupMonitor() {
        // Initialize the notch window
        let contentRect = NSRect(x: 0, y: 0, width: 230, height: 80) // Increase height for waveform
        let window = NotchWindow(contentRect: contentRect)
        
        let view = NotchView(manager: self)
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        self.notchWindow = window

        // Local monitor for when the app is active
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateFnKeyState(event)
            return event
        }
        
        // Global monitor for when any other app is active
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateFnKeyState(event)
        }
        
        // Timer to periodically re-check accessibility status
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isAccessibilityTrusted = AXIsProcessTrusted()
            }
        }
    }
    
    private func updateFnKeyState(_ event: NSEvent) {
        let isFunctionKey = event.modifierFlags.contains(.function)
        DispatchQueue.main.async {
            if isFunctionKey {
                if !self.isFnPressed {
                    self.isFnPressed = true
                    self.audioManager.startRecording()
                }
            } else {
                if self.isFnPressed {
                    self.isFnPressed = false
                    self.audioManager.stopRecording()
                }
            }
        }
    }
}

@main
struct AltWhisperApp: App {
    @StateObject private var keyboardManager = KeyboardManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    keyboardManager.setupMonitor()
                }
        }
    }
}
