import Foundation
import Observation
import SwiftUI

enum AppearanceTheme: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var next: AppearanceTheme {
        switch self {
        case .system: return .light
        case .light:  return .dark
        case .dark:   return .system
        }
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private static let retentionCapKey = "settings.retentionCap"
    private static let perFileSizeCapMBKey = "settings.perFileSizeCapMB"
    private static let excludedAppsKey = "settings.excludedApps"
    private static let appearanceKey = "settings.appearance"

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

    var appearance: AppearanceTheme {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
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
        if let raw = d.string(forKey: Self.appearanceKey),
           let theme = AppearanceTheme(rawValue: raw) {
            appearance = theme
        } else {
            appearance = .system
        }
    }
}
