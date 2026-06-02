import Foundation

struct TranslationResult {
    let sourceText: String
    let translatedText: String
    let detectedLanguage: String?
    let targetLanguage: String
}

final class GoogleTranslateService {
    enum TranslateError: LocalizedError {
        case emptyInput
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .emptyInput:
                return "Nothing to translate."
            case .invalidResponse:
                return "Could not read the translation response."
            }
        }
    }

    func translate(_ text: String, targetLanguage: String = "vi") async throws -> TranslationResult {
        let trimmedText = normalizeInput(text)
        guard !trimmedText.isEmpty else { throw TranslateError.emptyInput }
        let preparedText = prepareSourceText(trimmedText)
        let protectedInput = protectGlossaryTerms(preparedText)

        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: targetLanguage),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: protectedInput.text)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [Any],
              let sentences = root.first as? [Any] else {
            throw TranslateError.invalidResponse
        }

        let rawTranslatedText = sentences.compactMap { sentence -> String? in
            guard let parts = sentence as? [Any] else { return nil }
            return parts.first as? String
        }.joined()
        let translatedText = postProcessTranslation(
            restoreGlossaryTerms(rawTranslatedText, terms: protectedInput.terms),
            targetLanguage: targetLanguage
        )

        let detectedLanguage = root.indices.contains(2) ? root[2] as? String : nil
        guard !translatedText.isEmpty else { throw TranslateError.invalidResponse }

        return TranslationResult(
            sourceText: trimmedText,
            translatedText: translatedText,
            detectedLanguage: detectedLanguage,
            targetLanguage: targetLanguage
        )
    }

    private func normalizeInput(_ text: String) -> String {
        let normalizedNewlines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalizedNewlines
            .components(separatedBy: "\n\n")
            .map { paragraph in
                paragraph
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prepareSourceText(_ text: String) -> String {
        let pattern = #"^Reaching out from ([A-Z][A-Za-z0-9]*(?:\s+[A-Z][A-Za-z0-9]*){0,4}) with an important update about"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "$1 has an important update about"
        )
    }

    private func protectGlossaryTerms(_ text: String) -> (text: String, terms: [String: String]) {
        let glossaryTerms = ["Augment Code"]
        var protectedText = text
        var terms: [String: String] = [:]

        for (index, term) in glossaryTerms.enumerated() where protectedText.contains(term) {
            let placeholder = "ZXBRAND\(index)ZX"
            protectedText = protectedText.replacingOccurrences(of: term, with: placeholder)
            terms[placeholder] = term
        }

        return (protectedText, terms)
    }

    private func restoreGlossaryTerms(_ text: String, terms: [String: String]) -> String {
        var restoredText = text

        for (placeholder, term) in terms {
            restoredText = restoredText.replacingOccurrences(of: placeholder, with: term)
            restoredText = restoredText.replacingOccurrences(of: placeholder.lowercased(), with: term)
            restoredText = restoredText.replacingOccurrences(of: "Mã tăng cường", with: term)
        }

        return restoredText
    }

    private func postProcessTranslation(_ text: String, targetLanguage: String) -> String {
        guard targetLanguage == "vi" else {
            return text
        }

        return text
            .replacingOccurrences(of: "nền tảng đại lý", with: "nền tảng agent")
            .replacingOccurrences(of: "Nền tảng đại lý", with: "Nền tảng agent")
            .replacingOccurrences(of: "gỡ bỏ cấp Cộng đồng", with: "ngừng cung cấp gói Cộng đồng")
            .replacingOccurrences(of: "loại bỏ cấp Cộng đồng", with: "ngừng cung cấp gói Cộng đồng")
            .replacingOccurrences(of: "kế hoạch trả phí", with: "gói trả phí")
            .replacingOccurrences(of: "kế hoạch trả tiền", with: "gói trả phí")
    }
}
