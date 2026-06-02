import Foundation

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var startupOnBoot: Bool {
        get { defaults.bool(forKey: "startupOnBoot") }
        set { defaults.set(newValue, forKey: "startupOnBoot") }
    }

    var screenshotEnabled: Bool {
        get { defaults.object(forKey: "screenshotEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "screenshotEnabled") }
    }

    var popupEnabled: Bool {
        get { defaults.object(forKey: "popupEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "popupEnabled") }
    }

    var pasteTranslateEnabled: Bool {
        get { defaults.object(forKey: "pasteTranslateEnabled") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "pasteTranslateEnabled") }
    }

    var automaticChineseEnglish: Bool {
        get { defaults.bool(forKey: "automaticChineseEnglish") }
        set { defaults.set(newValue, forKey: "automaticChineseEnglish") }
    }

    var geminiAPIKey: String {
        get { defaults.string(forKey: "geminiAPIKey") ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "geminiAPIKey") }
    }

    var ocrLanguage: OCRLanguage {
        get {
            guard let rawValue = defaults.string(forKey: "ocrLanguage"),
                  let language = OCRLanguage(rawValue: rawValue) else {
                return .automatic
            }
            return language
        }
        set { defaults.set(newValue.rawValue, forKey: "ocrLanguage") }
    }
}

enum OCRLanguage: String, CaseIterable {
    case automatic
    case english
    case vietnamese
    case simplifiedChinese
    case traditionalChinese

    var title: String {
        switch self {
        case .automatic:
            return "Automatically detect language"
        case .english:
            return "English"
        case .vietnamese:
            return "Vietnamese"
        case .simplifiedChinese:
            return "Chinese Simplified"
        case .traditionalChinese:
            return "Chinese Traditional"
        }
    }

    var recognitionLanguageCode: String? {
        switch self {
        case .automatic:
            return nil
        case .english:
            return "en-US"
        case .vietnamese:
            return "vi-VN"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }

    var recognitionLanguageCodes: [String] {
        if let recognitionLanguageCode {
            return [recognitionLanguageCode]
        }

        return ["en-US", "vi-VN", "zh-Hans", "zh-Hant"]
    }
}
