import Foundation

enum AppResource {
    static func url(forResource name: String, withExtension fileExtension: String) -> URL? {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("TranslateD_TranslateD.bundle"),
           let bundle = Bundle(url: resourceURL),
           let url = bundle.url(forResource: name, withExtension: fileExtension) {
            return url
        }

        if let url = Bundle.main.url(forResource: name, withExtension: fileExtension) {
            return url
        }

        return Bundle.module.url(forResource: name, withExtension: fileExtension)
    }
}
