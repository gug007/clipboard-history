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
    private static let excludedAppsDefaultsVersionKey = "settings.excludedAppsDefaultsVersion"
    private static let appearanceKey = "settings.appearance"
    private static let overlayWidthKey = "settings.overlayWidth"
    private static let overlayHeightKey = "settings.overlayHeight"
    private static let currentExcludedAppsDefaultsVersion = 2

    static let defaultRetentionCap = 1_000
    static let defaultPerFileSizeCapMB = 10
    static let defaultOverlaySize = CGSize(width: 720, height: 480)
    static let minOverlaySize = CGSize(width: 560, height: 340)
    static let maxOverlaySize = CGSize(width: 1_400, height: 1_000)
    static let defaultExcludedApps: [String] = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.Dashlane",
        "com.dashlane.5",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.lastpass.LastPassMacApp",
        "com.lastpass.lastpassforsafari",
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

    private var overlaySizeStorage: CGSize

    /// Last size the user dragged the overlay panel to. Clamped on the way in
    /// and out so a size stored on a large display can never leave the panel
    /// unusable — or invisible — on a smaller one.
    var overlaySize: CGSize {
        get { overlaySizeStorage }
        set {
            let clamped = Self.clampOverlaySize(newValue)
            guard clamped != overlaySizeStorage else { return }
            overlaySizeStorage = clamped
            UserDefaults.standard.set(Double(clamped.width), forKey: Self.overlayWidthKey)
            UserDefaults.standard.set(Double(clamped.height), forKey: Self.overlayHeightKey)
        }
    }

    static func clampOverlaySize(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width.rounded(), minOverlaySize.width), maxOverlaySize.width),
            height: min(max(size.height.rounded(), minOverlaySize.height), maxOverlaySize.height)
        )
    }

    private init() {
        let d = UserDefaults.standard
        retentionCap = (d.object(forKey: Self.retentionCapKey) as? Int) ?? Self.defaultRetentionCap
        perFileSizeCapMB = (d.object(forKey: Self.perFileSizeCapMBKey) as? Int) ?? Self.defaultPerFileSizeCapMB
        if let stored = d.stringArray(forKey: Self.excludedAppsKey) {
            var upgraded = stored
            if d.integer(forKey: Self.excludedAppsDefaultsVersionKey)
                < Self.currentExcludedAppsDefaultsVersion {
                for bundleID in [
                    "com.1password.1password",
                    "com.dashlane.Dashlane",
                    "com.lastpass.lastpassforsafari"
                ] where !upgraded.contains(bundleID) {
                    upgraded.append(bundleID)
                }
                d.set(upgraded, forKey: Self.excludedAppsKey)
            }
            excludedApps = upgraded
        } else {
            excludedApps = Self.defaultExcludedApps
        }
        d.set(
            Self.currentExcludedAppsDefaultsVersion,
            forKey: Self.excludedAppsDefaultsVersionKey
        )
        if let raw = d.string(forKey: Self.appearanceKey),
           let theme = AppearanceTheme(rawValue: raw) {
            appearance = theme
        } else {
            appearance = .system
        }
        let storedWidth = d.object(forKey: Self.overlayWidthKey) as? Double
        let storedHeight = d.object(forKey: Self.overlayHeightKey) as? Double
        if let storedWidth, let storedHeight {
            overlaySizeStorage = Self.clampOverlaySize(
                CGSize(width: storedWidth, height: storedHeight)
            )
        } else {
            overlaySizeStorage = Self.defaultOverlaySize
        }
    }
}
