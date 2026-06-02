import Foundation

final class GeminiTranslateService {
    enum GeminiError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add your Gemini API key in Settings."
            case .invalidResponse:
                return "Could not read the Gemini response."
            case .requestFailed(let message):
                return message
            }
        }
    }

    func translate(_ text: String, targetLanguageName: String, apiKey: String) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw GoogleTranslateService.TranslateError.emptyInput }

        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAPIKey.isEmpty else { throw GeminiError.missingAPIKey }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(cleanAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(text: trimmedText, targetLanguageName: targetLanguageName))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw GeminiError.requestFailed(parseErrorMessage(from: data) ?? "Gemini request failed with status \(httpResponse.statusCode).")
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.invalidResponse
        }

        let translatedText = parts.compactMap { $0["text"] as? String }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translatedText.isEmpty else { throw GeminiError.invalidResponse }

        return translatedText
    }

    private func requestBody(text: String, targetLanguageName: String) -> [String: Any] {
        [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "text": """
                            Translate the following text into \(targetLanguageName).
                            Return only the translated text. Do not add explanations.
                            Preserve product names, company names, code identifiers, and technical terms when appropriate.

                            Text:
                            \(text)
                            """
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2
            ]
        ]
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any] else {
            return nil
        }

        return error["message"] as? String
    }
}
