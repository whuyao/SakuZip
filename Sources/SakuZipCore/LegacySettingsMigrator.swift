import Foundation

public enum LegacySettingsMigrator {
    private static let migrationMarker = "didMigrateLegacySettings"
    private static let migratedKeys = [
        L10n.languageStorageKey,
        "workflowPresetsV2",
        "customWorkflows"
    ]

    public static func migrateIfNeeded(
        from legacyDomain: String = "com.yaoyao.ycompress",
        to currentDefaults: UserDefaults = .standard
    ) {
        guard !currentDefaults.bool(forKey: migrationMarker) else { return }

        if let legacyValues = currentDefaults.persistentDomain(
            forName: legacyDomain
        ) {
            for key in migratedKeys
            where currentDefaults.object(forKey: key) == nil {
                currentDefaults.set(legacyValues[key], forKey: key)
            }
        }

        currentDefaults.set(true, forKey: migrationMarker)
    }
}
