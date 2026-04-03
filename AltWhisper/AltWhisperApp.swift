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
    let transcriptionService = TranscriptionService()
    let textInjector = TextInjector()
    private var cancellables = Set<AnyCancellable>()
    private var notchWindow: NotchWindow?
    private var targetApp: NSRunningApplication?  // The app that was active when fn was pressed

    override init() {
        super.init()
        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
    }

    func setupMonitor() {
        // Prompt for accessibility if we don't have it yet
        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptOption: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
        
        let contentRect = NSRect(x: 0, y: 0, width: 230, height: 80)
        let window = NotchWindow(contentRect: contentRect)
        
        let view = NotchView(manager: self)
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        self.notchWindow = window

        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateFnKeyState(event)
            return event
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateFnKeyState(event)
        }
        
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
                    // Snapshot the frontmost app NOW, before anything changes focus
                    self.targetApp = NSWorkspace.shared.frontmostApplication
                    print("🎯 Target app: \(self.targetApp?.localizedName ?? "unknown")")
                    self.audioManager.startRecording()
                }
            } else {
                if self.isFnPressed {
                    self.isFnPressed = false
                    self.audioManager.stopRecording()
                    
                    // Send recording to Groq for transcription
                    if let recordingURL = self.audioManager.getRecordingURL() {
                        self.transcriptionService.transcribe(fileURL: recordingURL) { [weak self] text in
                            guard let self = self, let text = text, !text.isEmpty else {
                                print("⚠️  No transcription text to inject")
                                return
                            }
                            
                            DispatchQueue.main.async {
                                print("⌨️  Injecting transcribed text into \(self.targetApp?.localizedName ?? "unknown"): \(text)")
                                self.textInjector.injectText(text, into: self.targetApp)
                            }
                        }
                    }
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
