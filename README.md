# Clipboard History

**Never lose what you copy.**

Clipboard History remembers everything you copy on your Mac — every link, every paragraph, every screenshot, every file. Press ⇧⌘V and bring any of it back.

Free. Open source. Works offline. Skips passwords automatically.

[Download for Mac](https://github.com/gug007/clipboard-history/releases) · [Website](https://clipboard-history.cc/)

![Clipboard History demo](website/uploads/clipboard-history-demo.gif)

## What it does

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
- **Doesn't watch password fields.** Whenever you're typing into a password box or the Mac lock screen, recording pauses automatically.
- **Safe to install.** Signed and approved by Apple, so macOS opens it without warnings. Updates are checked over a secure connection and verified before installing.

## Install

1. Download the latest `ClipboardHistory-<version>.dmg` from [Releases](https://github.com/gug007/clipboard-history/releases).
2. Open the DMG and drag **Clipboard History** into your Applications folder.
3. Open it from Applications. A small clipboard icon appears at the top of your screen, in the menu bar — that's the app. There's no Dock icon and no window to close; it just sits up there and works.
4. The first time you press ⇧⌘V, macOS will ask for permission to paste for you (it calls this "Accessibility"). Click **Allow** and you're set. If you'd rather not, the clip still lands on your clipboard — just press ⌘V yourself.

Works on any Mac running macOS 14 (Sonoma) or later, on both Apple Silicon and Intel. About 6 MB.

## How to use it

Keep copying like you normally do. When you need something back:

1. Press **⇧⌘V** anywhere — Mail, Safari, Slack, your code editor, wherever you're typing.
2. A list of your recent copies appears.
3. Use **↑/↓** to highlight the one you want.
4. Press **Return** to paste it.

A few handy tricks:
- Start typing to filter the list — search works inside text, links, and filenames.
- Press **⌘D** to star a clip. Starred clips never get cleaned up — great for your address, your email signature, that one Slack emoji.
- Press **⌘1** through **⌘9** to grab the first nine items instantly, no arrows needed.

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

You can change ⇧⌘V to any shortcut you like in Settings.

## What's next

Optional iCloud sync, so your starred clips can follow you between Macs. It'll be opt-in — off by default — and your history stays on your computer if you don't turn it on. Not shipping yet.

## For developers

Want to build it yourself or look at the code:

```
git clone https://github.com/gug007/clipboard-history.git
open "Clipboard History/Clipboard History.xcodeproj"
```

Requires macOS 14+, Xcode 15+, Swift 5.9+. SwiftPM resolves GRDB, KeyboardShortcuts, and Sparkle on first build. Release artifacts are produced by `scripts/release.sh` and `scripts/create-dmg.sh`.
