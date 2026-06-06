import Foundation

enum L10n {
    private static let englishKey = "tcl_remote_english_enabled"

    static func tr(_ key: String) -> String {
        let languageCode = UserDefaults.standard.bool(forKey: englishKey) ? "en" : "vi"
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        return NSLocalizedString(key, comment: "")
    }
}
