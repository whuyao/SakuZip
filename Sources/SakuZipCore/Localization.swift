import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: L10n.string("跟随系统")
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        case .japanese: "日本語"
        }
    }

    fileprivate var localizationIdentifier: String? {
        switch self {
        case .system: nil
        case .simplifiedChinese: "zh-Hans"
        case .english: "en"
        case .japanese: "ja"
        }
    }
}

public enum L10n {
    public static let languageStorageKey = "appLanguage"

    public static let launchLanguage: AppLanguage = {
        guard let saved = UserDefaults.standard.string(forKey: languageStorageKey),
              let language = AppLanguage(rawValue: saved) else {
            return .system
        }
        return language
    }()

    public static let launchLocale: Locale = {
        guard let identifier = launchLanguage.localizationIdentifier else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: identifier)
    }()

    private static let localizationBundle: Bundle = {
        guard let identifier = launchLanguage.localizationIdentifier,
              let path = Bundle.main.path(
                  forResource: identifier,
                  ofType: "lproj"
              ),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }()

    public static func string(_ key: String) -> String {
        localizationBundle.localizedString(forKey: key, value: key, table: nil)
    }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: string(key),
            locale: launchLocale,
            arguments: arguments
        )
    }
}
