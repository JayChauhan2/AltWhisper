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
    @Published var audioLevel: Float = 0.0
    let audioManager = AudioManager()
    private var cancellables = Set<AnyCancellable>()
    private var notchWindow: NotchWindow?

    override init() {
        super.init()
        // Forward audioLevel changes from AudioManager to this object
        // so SwiftUI views observing KeyboardManager will re-render
        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
    }

    func setupMonitor() {
        // Initialize the notch window
        let contentRect = NSRect(x: 0, y: 0, width: 230, height: 80)
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
