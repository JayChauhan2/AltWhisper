import Foundation
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var audioLevel: Float = 0.0
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?

    override init() {
        super.init()
        setupPermissions()
    }

    private func setupPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                print("Microphone access granted")
            } else {
                print("Microphone access denied")
            }
        }
    }

    func startRecording() {
        do {
            let fileName = "recording_\(currentTimestamp()).m4a"
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            recordingURL = documentsPath.appendingPathComponent(fileName)

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            print("Started recording at: \(recordingURL!.path)")

            startMonitoring()
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        stopMonitoring()
        print("Stopped recording. File saved at: \(recordingURL?.path ?? "unknown")")
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.audioRecorder?.updateMeters()
            let power = self?.audioRecorder?.averagePower(forChannel: 0) ?? -60.0
            
            // Normalize the level from db (-60 to 0) to 0.0 to 1.0
            let level = max(0.2, CGFloat(power + 60) / 60.0)
            DispatchQueue.main.async {
                self?.audioLevel = Float(level)
            }
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async {
            self.audioLevel = 0.0
        }
    }

    private func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    func getRecordingURL() -> URL? {
        return recordingURL
    }
}
