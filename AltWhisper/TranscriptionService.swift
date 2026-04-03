import Foundation

class TranscriptionService {
    private let apiKey: String
    private let transcribeEndpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
    private let chatEndpoint = "https://api.groq.com/openai/v1/chat/completions"
    
    init() {
        self.apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
        if apiKey.isEmpty {
            print("⚠️  GROQ_API_KEY not set. Set it in Xcode: Product > Scheme > Edit Scheme > Run > Environment Variables")
        }
    }
    
    func transcribe(fileURL: URL, completion: @escaping (String?) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ Cannot transcribe: GROQ_API_KEY is not set")
            completion(nil)
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Audio file not found at: \(fileURL.path)")
            completion(nil)
            return
        }
        
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read audio file")
            completion(nil)
            return
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: transcribeEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3-turbo\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 Sending audio to Groq for transcription...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Transcription request failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let data = data else {
                print("❌ No data received from Groq")
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let rawText = json["text"] as? String {
                    print("📝 Raw transcription: \(rawText)")
                    self.formatWithLLM(rawText, completion: completion)
                } else {
                    let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"
                    print("⚠️  Unexpected response: \(rawResponse)")
                    completion(nil)
                }
            } catch {
                let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"
                print("❌ Failed to parse response: \(rawResponse)")
                completion(nil)
            }
        }.resume()
    }
    
    private func formatWithLLM(_ rawText: String, completion: @escaping (String?) -> Void) {
        let systemPrompt = """
        You are a voice transcription formatter. Your job is to clean up raw speech-to-text output into polished, natural text ready to be pasted.

        Rules:
        - Resolve self-corrections: if the speaker corrects themselves (e.g. "at 5 o'clock, actually no, 4 o'clock"), apply the correction and remove the false start
        - Remove filler words like "um", "uh", "like", "you know" when they add no meaning
        - Fix punctuation and capitalisation
        - Preserve the speaker's intent and tone exactly — do not rephrase or summarise
        - Output ONLY the final cleaned text, nothing else — no explanations, no quotes, no labels
        """
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": rawText]
        ]
        
        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": messages,
            "temperature": 0.0
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            print("❌ Failed to encode chat request")
            completion(rawText)
            return
        }
        
        var request = URLRequest(url: URL(string: chatEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        print("✨ Formatting transcription with LLM...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Formatting request failed: \(error.localizedDescription)")
                completion(rawText)
                return
            }
            guard let data = data else {
                print("❌ No data from formatting call")
                completion(rawText)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let message = first["message"] as? [String: Any],
                   let formattedText = message["content"] as? String {
                    let cleaned = formattedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("✅ Formatted text: \(cleaned)")
                    completion(cleaned)
                } else {
                    let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"
                    print("⚠️  Unexpected formatting response: \(rawResponse)")
                    completion(rawText)
                }
            } catch {
                print("❌ Failed to parse formatting response")
                completion(rawText)
            }
        }.resume()
    }
}
