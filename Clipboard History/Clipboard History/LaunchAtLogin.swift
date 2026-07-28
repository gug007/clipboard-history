import Foundation
import Observation
import ServiceManagement

@Observable
final class LaunchAtLogin {
    static let shared = LaunchAtLogin()

    enum State {
        case enabled
        case disabled
        case requiresApproval
    }

    private static let defaultAppliedKey = "LaunchAtLogin.defaultApplied"

    private let service = SMAppService.mainApp
    private(set) var state: State

    var isEnabled: Bool { state == .enabled }

    private init() {
        state = Self.read(service)
        recordDefaultAsHandledIfNeeded()
    }

    /// Older builds silently registered the app as a login item on first launch.
    /// New installs make that choice explicitly during onboarding instead.
    private func recordDefaultAsHandledIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Self.defaultAppliedKey) else { return }
        d.set(true, forKey: Self.defaultAppliedKey)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status != .notRegistered {
                    try service.unregister()
                }
            }
        } catch {
            print("[LaunchAtLogin] toggle failed: \(error)")
        }
        state = Self.read(service)
    }

    func refresh() {
        state = Self.read(service)
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func read(_ s: SMAppService) -> State {
        switch s.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered, .notFound: return .disabled
        @unknown default: return .disabled
        }
    }
}
