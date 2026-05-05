# Clipboard History

**Never lose what you copy.**

Clipboard History remembers everything you copy on your Mac — every link, every paragraph, every screenshot, every file. Press ⇧⌘V and bring any of it back.

Free. Open source. Works offline. Skips passwords automatically.

[Download for Mac](https://github.com/gug007/clipboard-history/releases) · [Website](https://clipboard-history.app/)

## A second brain for your clipboard

Every time you copy something new, the last thing is gone. Clipboard History remembers it all — quietly in the background — so you can paste any of it back, anytime.

- **Find anything you've ever copied.** Type a word or two and the matching clip jumps to the top — even something you copied last week. It searches inside text, links, and filenames. Instant.
- **One shortcut, anywhere.** Press ⇧⌘V in any app. Pick what you want with the arrow keys. Hit Return. It pastes right where you were typing.
- **Everything you copy.** Plain text, formatted text, links, photos, screenshots, and files. Even a whole folder of files. It all comes back.
- **Save your favorites.** Star the clips you reuse — your address, your bank details, that one Slack emoji. Or sort related clips into named groups. They never get cleaned up.
- **No clutter.** Copy the same thing twice in a row? It doesn't make a duplicate. Your list stays clean and easy to scan.
- **Barely any space.** Copy a 5 GB file and it costs a few kilobytes — the app remembers *where* the file lives, not the file itself. By default it keeps your last 1,000 clips; you can crank that up to 10,000.

## Your clipboard. Yours alone.

Your clipboard has private things in it — passwords half-typed, a friend's address, a credit card number. The app treats it that way.

- **Stays on your Mac. Always.** Your clipboard history never leaves your computer. No account. Nothing uploaded. No telemetry.
- **Ignores your password manager.** When you copy from 1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain Access, or LastPass, the app pretends it didn't see it. You can add other apps to the list.
- **Doesn't watch password fields.** Whenever you're typing into a password box, a sudo prompt, or the Mac lock screen, recording pauses automatically.
- **Safe to install.** Signed and notarized by Apple, so macOS opens it without warnings. Updates are checked over a secure connection and verified before installing.

## Install

1. Download the latest `ClipboardHistory-<version>.dmg` from [Releases](https://github.com/gug007/clipboard-history/releases).
2. Open the DMG and drag the app to Applications.
3. Launch it. A clipboard icon appears in the menu bar — there's no Dock icon.
4. The first time you paste, macOS will ask for Accessibility permission (needed for auto-paste). If you decline, the item still lands on your clipboard — just press ⌘V manually.

Works on any Mac running macOS 14 (Sonoma) or later, on both Apple Silicon and Intel. About 6 MB.

## Keyboard shortcuts

| Action | Keys |
| --- | --- |
| Open your clipboard history | ⇧⌘V |
| Move up or down the list | ↑ ↓ |
| Paste the highlighted item | ⏎ |
| Pick the 1st–9th item directly | ⌘1–9 |
| Switch between groups | ⌥1–9 |
| Star or un-star a clip | ⌘D |
| Delete a clip | ⌘⌫ |
| Show file in Finder | ⌘R |
| Jump to your starred clips | ⇧F |
| Close the window | ⎋ |

You can rebind ⇧⌘V in Settings.

## Build from source

```
git clone https://github.com/gug007/clipboard-history.git
open "Clipboard History/Clipboard History.xcodeproj"
```

Requires macOS 14+, Xcode 15+, Swift 5.9+. SwiftPM resolves GRDB, KeyboardShortcuts, and Sparkle on first build. Release artifacts are produced by `scripts/release.sh` and `scripts/create-dmg.sh`.

## Roadmap

iCloud sync via CKSyncEngine on the user's private database — opt-in, not yet shipping.

## License

See [LICENSE](LICENSE).
