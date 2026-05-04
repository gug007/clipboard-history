import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut that opens the clipboard history overlay.
    /// Default is ⇧⌘V; the user can change it in Settings → General.
    static let openHistory = Self(
        "openHistory",
        default: .init(.v, modifiers: [.command, .shift])
    )
}

final class HotkeyService {
    init(onFire: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .openHistory) {
            onFire()
        }
    }
}
