import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private static let retentionCapKey = "settings.retentionCap"
    private static let perFileSizeCapMBKey = "settings.perFileSizeCapMB"
    private static let excludedAppsKey = "settings.excludedApps"

    static let defaultRetentionCap = 1_000
    static let defaultPerFileSizeCapMB = 10
    static let defaultExcludedApps: [String] = [
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.5",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.lastpass.LastPassMacApp",
        "org.keepassxc.keepassxc"
    ]

    var retentionCap: Int {
        didSet {
            UserDefaults.standard.set(retentionCap, forKey: Self.retentionCapKey)
        }
    }

    var perFileSizeCapMB: Int {
        didSet {
            UserDefaults.standard.set(perFileSizeCapMB, forKey: Self.perFileSizeCapMBKey)
        }
    }

    var excludedApps: [String] {
        didSet {
            UserDefaults.standard.set(excludedApps, forKey: Self.excludedAppsKey)
        }
    }

    private init() {
        let d = UserDefaults.standard
        retentionCap = (d.object(forKey: Self.retentionCapKey) as? Int) ?? Self.defaultRetentionCap
        perFileSizeCapMB = (d.object(forKey: Self.perFileSizeCapMBKey) as? Int) ?? Self.defaultPerFileSizeCapMB
        if let stored = d.stringArray(forKey: Self.excludedAppsKey) {
            excludedApps = stored
        } else {
            excludedApps = Self.defaultExcludedApps
        }
    }
}
