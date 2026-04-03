import Foundation

class TranscriptionService {
    private let apiKey: String
    private let endpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
    
    init() {
        // Read API key from environment or hardcode for now
        self.apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
        if apiKey.isEmpty {
            print("⚠️  GROQ_API_KEY not set. Set it in Xcode: Product > Scheme > Edit Scheme > Run > Environment Variables")
        }
    }
    
    func transcribe(fileURL: URL) {
        guard !apiKey.isEmpty else {
            print("❌ Cannot transcribe: GROQ_API_KEY is not set")
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Audio file not found at: \(fileURL.path)")
            return
        }
        
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read audio file")
            return
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        var body = Data()
        
        // Add the file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add the model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3-turbo\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 Sending audio to Groq for transcription...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Transcription request failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ No data received from Groq")
                return
            }
            
            // Parse the JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    print("📝 Transcription: \(text)")
                } else {
                    // Print raw response for debugging
                    let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"
                    print("⚠️  Unexpected response: \(rawResponse)")
                }
            } catch {
                let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"
                print("❌ Failed to parse response: \(rawResponse)")
            }
        }.resume()
    }
}
