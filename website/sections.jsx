/* global React, Icon */

function PrivacySection() {
  const points = [
    {
      icon: <Icon.database/>,
      tone: "blue",
      title: "Stays on your Mac",
      body: <>Your history lives in a single local database file. No account. No uploads. No telemetry. The only thing the app ever connects to is its own update check.</>,
    },
    {
      icon: <Icon.lock/>,
      tone: "purple",
      title: "Skips password managers",
      body: <>Anything you copy from 1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain, or LastPass is ignored. Add any app to the skip list in Settings.</>,
    },
    {
      icon: <Icon.shield/>,
      tone: "amber",
      title: "Honors confidential copies",
      body: <>When any app marks a copy as concealed or transient — the standard convention password managers use — it's never recorded, even if that app isn't on the list.</>,
    },
    {
      icon: <Icon.pause/>,
      tone: "green",
      title: "Pause with one click",
      body: <>Hit Pause Recording in the menu bar and nothing is captured until you resume — even across restarts. The overlay shows a Paused badge so you always know.</>,
    },
  ];

  const skipped = [
    { name: "1Password",       color: "#0572ec", letter: "1" },
    { name: "Bitwarden",       color: "#175ddc", letter: "B" },
    { name: "Dashlane",        color: "#007c89", letter: "D" },
    { name: "KeePassXC",       color: "#3c4d5c", letter: "K" },
    { name: "Apple Passwords", color: "#9aa0a6", letter: "P" },
    { name: "Keychain",        color: "#3a3a3c", letter: "K" },
    { name: "LastPass",        color: "#d32d27", letter: "L" },
  ];

  return (
    <section className="privacy" aria-labelledby="privacy-heading">
      <div className="container">
        <div className="section-eyebrow">Privacy</div>
        <h2 id="privacy-heading" className="section-title">Your clipboard, yours alone.</h2>
        <p className="section-lede">
          Your clipboard has private things in it — an address, a card number, that message you almost sent. The app treats it that way.
        </p>

        <div className="privacy-grid">
          <ul className="privacy-points" aria-label="Privacy guarantees">
            {points.map((p, i) => (
              <li key={i} className="privacy-point" data-tone={p.tone}>
                <div className="pp-icon" aria-hidden="true">{p.icon}</div>
                <div>
                  <h3>{p.title}</h3>
                  <p>{p.body}</p>
                </div>
              </li>
            ))}
          </ul>
          <div className="privacy-aside">
            <div className="skip-card" role="group" aria-labelledby="skip-card-title">
              <div className="skip-card-head" id="skip-card-title">
                <span aria-hidden="true"><Icon.shield/></span> Password managers it ignores from day one
              </div>
              <ul className="skip-grid" aria-label="Ignored password managers">
                {skipped.map((a, i) => (
                  <li key={i} className="skip-chip">
                    <div className="app-icon" style={{background: a.color}} aria-hidden="true">{a.letter}</div>
                    <span>{a.name}</span>
                  </li>
                ))}
                <li className="skip-chip skip-chip-add" aria-label="Add more apps in Settings">
                  <div className="app-icon app-icon-add" aria-hidden="true">+</div>
                  <span>Add more in Settings</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function CheatsheetSection() {
  const shortcuts = [
    { label: "Open clipboard history",            keys: [{k:"⇧"}, {k:"⌘"}, {k:"V"}] },
    { label: "Search",                            keys: [{k:"Just type…", w:true}] },
    { label: "Move up or down",                   keys: [{k:"↑"}, {k:"↓"}] },
    { label: "Paste highlighted item",            keys: [{k:"⏎ Return", w:true}] },
    { label: "Paste item 1–9 directly",           keys: [{k:"⌘"}, {k:"1–9", w:true}] },
    { label: "Switch tabs — All, Favorites, groups", keys: [{k:"⌥"}, {k:"1–9", w:true}] },
    { label: "Star or un-star",                   keys: [{k:"⌘"}, {k:"D"}] },
    { label: "Delete",                            keys: [{k:"⌘"}, {k:"⌫"}] },
    { label: "Reveal file in Finder",             keys: [{k:"⌘"}, {k:"R"}] },
    { label: "Jump to Favorites",                 keys: [{k:"⇧"}, {k:"⌘"}, {k:"F"}] },
    { label: "Close",                             keys: [{k:"⎋ Esc", w:true}] },
  ];

  return (
    <section aria-labelledby="shortcuts-heading">
      <div className="container">
        <div className="section-eyebrow">Keyboard shortcuts</div>
        <h2 id="shortcuts-heading" className="section-title">Built for fast hands.</h2>
        <p className="section-lede">
          You never have to touch the mouse. And <span className="kbd-combo" role="img" aria-label="Shift Command V"><span className="kbd" aria-hidden="true">⇧</span><span className="kbd" aria-hidden="true">⌘</span><span className="kbd" aria-hidden="true">V</span></span> is just the default — record any shortcut you like in Settings.
        </p>
        <div className="cheatsheet">
          <dl className="shortcut-grid">
            {shortcuts.map((s, i) => (
              <div key={i} className="shortcut-row">
                <dt className="label">{s.label}</dt>
                <dd className="keys">
                  {s.keys.map((key, j) => (
                    <React.Fragment key={j}>
                      {j > 0 && <span className="plus" aria-hidden="true">+</span>}
                      <span className={"key-cap" + (key.w ? " wide" : "")}>{key.k}</span>
                    </React.Fragment>
                  ))}
                </dd>
              </div>
            ))}
          </dl>
        </div>
      </div>
    </section>
  );
}

function FAQSection() {
  const faqs = [
    { q: "Is Clipboard History free?", a: "Yes. Free, open source, no account, no trial, no ads. The code is on GitHub if you want to look at it." },
    { q: "Will it record my passwords?", a: "No. Anything copied from 1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain Access, or LastPass is skipped. Beyond that list, anything any app marks as concealed or transient on the clipboard — the standard convention password managers follow — is never recorded either. You can add more apps to the skip list in Settings → Privacy, or pause recording entirely from the menu bar." },
    { q: "Which Macs does it work on?", a: "Any Mac running macOS 14 (Sonoma) or newer. Apple Silicon and Intel both supported." },
    { q: "Will it slow down my Mac?", a: "No. The app is about 5 MB and spends its life doing one cheap thing: glancing at the clipboard twice a second. Most people forget it's running." },
    { q: "How is this different from the built-in macOS clipboard?", a: "macOS only remembers the last thing you copied. Copy something new and the previous one is gone. Clipboard History keeps your last 1,000 items by default (adjustable from 100 to 10,000 in Settings) so you can paste any of them back with Shift + Command + V. Starred clips and clips you've put in a group are never auto-removed." },
    { q: "How does it compare to Paste, Maccy, or Alfred's clipboard?", a: "Honestly: it's free, open source, and tiny (~5 MB). Paste is paid and syncs across devices. Maccy is also free and open source — a great alternative if you prefer it. Alfred's clipboard comes bundled with the Powerpack. Clipboard History focuses on doing one thing well, with privacy as the default. If you need iCloud sync between Macs, pick something else." },
    { q: "Does it sync between my Macs?", a: "No, and it won't. Your clipboard often contains passwords, private messages, and tokens — sending that to a server (even Apple's) is a tradeoff we don't want to make on your behalf. Clipboard History stays on the Mac it's installed on." },
    { q: "Where is my clipboard data stored?", a: "In a single SQLite file on your Mac at ~/Library/Application Support/Clipboard History/clipboard.sqlite. Nothing is uploaded anywhere. The file is usually a few hundred kilobytes since the app stores the location of large files, not a copy." },
    { q: "What about copied files and folders?", a: "Files and folders you copy in Finder are saved by reference — the app remembers where each file lives, plus a small preview thumbnail, so a 5 GB video costs a few kilobytes. Return pastes the real file, Command + R reveals it in Finder, and clicking the thumbnail shows a quick preview. If the original gets moved or deleted, the clip is flagged so you're never surprised. One honest limitation: images copied straight to the clipboard — a screenshot captured to clipboard, or a browser's Copy Image — aren't recorded yet. Copy the image as a file and it works." },
    { q: "Can I change the shortcut? The theme?", a: "Both. Record any keyboard shortcut in Settings → General — Shift + Command + V is just the default. And the app follows your choice of System, Light, or Dark appearance: switch it in Settings or with the sun/moon button right inside the overlay." },
    { q: "Does it start automatically?", a: "Yes. It registers itself as a login item on first launch so your history is always being kept, and you can turn that off in Settings → General. The app lives in your menu bar — there's no Dock icon to clutter things up." },
    { q: "Why does it need Accessibility permission?", a: "So it can paste for you when you press Return on a clip. macOS requires Accessibility access for any app to send keystrokes to another app. If you decline, the clip still lands on your clipboard and you can paste it manually with Command + V." },
    { q: "How do updates work?", a: "The download is signed and notarized by Apple, so you won't see the scary \"unidentified developer\" warning. The app checks for updates in the background and every update is cryptographically verified before it installs (it uses Sparkle, the standard open-source updater for Mac apps). You can also check manually from the menu bar." },
    { q: "How do I uninstall Clipboard History?", a: "Quit the app from the menu bar, then drag Clipboard History from your Applications folder to the Trash. To remove your stored history too, delete the folder at ~/Library/Application Support/Clipboard History. You can also wipe your history without uninstalling: Settings → Storage → Clear all history." },
  ];

  function onFaqToggle(e) {
    if (e.target.open) window.plausible && window.plausible('FAQ Expand');
  }

  return (
    <section aria-labelledby="faq-heading">
      <div className="container" style={{maxWidth: 820}}>
        <div className="section-eyebrow">Common questions</div>
        <h2 id="faq-heading" className="section-title">Questions, answered.</h2>
        <div className="faq-list" style={{marginTop: 40}}>
          {faqs.map((f, i) => (
            <details key={i} className="faq-item" onToggle={onFaqToggle}>
              <summary>{f.q}</summary>
              <p>{f.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

function DownloadSection() {
  return (
    <section className="download" id="download" aria-labelledby="download-heading">
      <div className="container">
        <div className="download-card">
          <h2 id="download-heading">Stop losing what you copy.</h2>
          <p>Free, open source, offline. Two minutes to install. Uninstall just as fast if it's not for you.</p>
          <div className="hero-actions">
            <a href="https://github.com/gug007/clipboard-history/releases" className="btn btn-primary btn-lg" onClick={() => window.plausible && window.plausible('Download Click')}>
              <span aria-hidden="true"><Icon.apple/></span> Download for Mac
            </a>
            <a href="https://github.com/gug007/clipboard-history" className="btn btn-ghost btn-lg">
              <span aria-hidden="true"><Icon.github/></span> View source on GitHub
            </a>
          </div>
          <ul className="download-meta" aria-label="Download details">
            <li className="download-meta-item" data-tone="blue"><span className="dm-icon" aria-hidden="true"><Icon.apple/></span> macOS 14 or later</li>
            <li className="download-meta-item" data-tone="green"><span className="dm-icon" aria-hidden="true"><Icon.download/></span> ~5 MB download</li>
            <li className="download-meta-item" data-tone="amber"><span className="dm-icon" aria-hidden="true"><Icon.bolt/></span> Apple Silicon and Intel</li>
            <li className="download-meta-item" data-tone="purple"><span className="dm-icon" aria-hidden="true"><Icon.shield/></span> Signed and notarized</li>
          </ul>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="foot" aria-label="Site footer">
      <div className="container foot-inner">
        <div>© 2026 Clipboard History · MIT License</div>
        <nav className="foot-links" aria-label="Footer">
          <a href="https://github.com/gug007/clipboard-history">GitHub</a>
          <a href="https://github.com/gug007/clipboard-history/releases">Releases</a>
          <a href="https://github.com/gug007/clipboard-history/blob/main/README.md">Docs</a>
          <a href="#privacy">Privacy</a>
        </nav>
      </div>
    </footer>
  );
}

window.PrivacySection = PrivacySection;
window.CheatsheetSection = CheatsheetSection;
window.FAQSection = FAQSection;
window.DownloadSection = DownloadSection;
window.Footer = Footer;
