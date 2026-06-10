import Foundation

struct AIIntentResponse: Codable {
    let action: String
    let dates: [String]?
    let times: AITimes?
    let value: String?
}

struct AITimes: Codable {
    let start: String?
    let end: String?
}

class AIBrainManager {
    static let shared = AIBrainManager()
    private init() {}
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let apiKey = Secrets.openAIApiKey
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = try createMultipartBody(fileURL: fileURL, boundary: boundary)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AIBrainManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Whisper STT failed: \(errorMsg)"])
        }
        
        struct TranscriptionResponse: Codable {
            let text: String
        }
        
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text
    }
    
    func parseIntent(transcript: String, currentMonthName: String, todayDate: String) async throws -> AIIntentResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let apiKey = Secrets.openAIApiKey
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
        You are the HC terminal logic. Extract actions from the user's spoken command.
        Today is \(todayDate). The currently displayed calendar month is \(currentMonthName).
        
        Return ONLY a JSON object with this schema:
        {
          "action": "select" | "remove" | "copy" | "navigate" | "camera" | "switch_view" | "time_mutation" | "unknown",
          "dates": ["YYYY-MM-DD", ...],
          "times": {
            "start": "HH:mm",
            "end": "HH:mm"
          },
          "value": "open" | "close" | "timesheet" | "calendar"
        }
        
        Rules:
        1. Resolve relative dates like "tomorrow", "yesterday", "next Monday" based on the todayDate.
        2. If the user mentions a date number but no month (e.g. "select the 15th"), assume it refers to the currently displayed month.
        3. If the user says "remove it" or "set it from 9 to 5", map to "remove" or "time_mutation" and return an empty dates list (the Swift receiver will resolve it to pronouns).
        4. "times" start/end must be strictly formatted as 24-hour "HH:mm" strings (e.g. "09:00", "17:00", "08:30").
        5. "switch to timesheet" => {"action": "switch_view", "value": "timesheet"}
        6. "switch to calendar" => {"action": "switch_view", "value": "calendar"}
        7. "open your vision" / "open eyes" => {"action": "camera", "value": "open"}
        8. "close your vision" / "close eyes" => {"action": "camera", "value": "close"}
        9. "copy report" / "export report" => {"action": "copy"}
        10. "go to october" => {"action": "navigate", "dates": ["2026-10-01"]} (navigate to the first day of that month)
        """
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript]
            ],
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AIBrainManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "LLM Intent Parse failed: \(errorMsg)"])
        }
        
        struct ChatCompletionResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw NSError(domain: "AIBrainManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "LLM response is empty"])
        }
        
        let contentData = content.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(AIIntentResponse.self, from: contentData)
        return parsed
    }
    
    private func createMultipartBody(fileURL: URL, boundary: String) throws -> Data {
        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-1\r\n".data(using: .utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        let filename = fileURL.lastPathComponent
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        let fileData = try Data(contentsOf: fileURL)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
}
