/* global React, Icon */

function PrivacySection() {
  const points = [
    {
      icon: <Icon.database/>,
      tone: "blue",
      title: "Stays on your Mac",
      body: <>Your clipboard history never leaves your computer. No account. No uploads. No telemetry.</>,
    },
    {
      icon: <Icon.lock/>,
      tone: "purple",
      title: "Skips password managers",
      body: <>Anything you copy from 1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain, or LastPass is ignored. Add more apps in Settings.</>,
    },
    {
      icon: <Icon.pause/>,
      tone: "amber",
      title: "Pauses for password fields",
      body: <>Recording stops automatically when you're typing in a password box or the Mac lock screen.</>,
    },
    {
      icon: <Icon.check/>,
      tone: "green",
      title: "Signed and approved by Apple",
      body: <>macOS opens it without warnings. Updates are verified before installing.</>,
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
          Your clipboard has private things in it — passwords half-typed, an address, a card number. The app treats it that way.
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
    { label: "Open clipboard history",          keys: [{k:"⇧"}, {k:"⌘"}, {k:"V"}] },
    { label: "Move up or down",                 keys: [{k:"↑"}, {k:"↓"}] },
    { label: "Paste highlighted item",          keys: [{k:"⏎ Return", w:true}] },
    { label: "Pick item 1–9 directly",          keys: [{k:"⌘"}, {k:"1–9", w:true}] },
    { label: "Switch groups",                   keys: [{k:"⌥"}, {k:"1–9", w:true}] },
    { label: "Star or un-star",                 keys: [{k:"⌘"}, {k:"D"}] },
    { label: "Delete",                          keys: [{k:"⌘"}, {k:"⌫"}] },
    { label: "Show in Finder",                  keys: [{k:"⌘"}, {k:"R"}] },
    { label: "Jump to starred",                 keys: [{k:"⇧"}, {k:"F"}] },
    { label: "Close",                           keys: [{k:"⎋ Esc", w:true}] },
  ];

  return (
    <section aria-labelledby="shortcuts-heading">
      <div className="container">
        <div className="section-eyebrow">Keyboard shortcuts</div>
        <h2 id="shortcuts-heading" className="section-title">Built for fast hands.</h2>
        <p className="section-lede">
          You never have to touch the mouse.
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
    { q: "Will it record my passwords?", a: "No. The app skips anything copied from 1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain Access, and LastPass. It also pauses recording when you're typing in a password field or sitting at the lock screen. You can add other apps to the skip list in Settings." },
    { q: "Which Macs does it work on?", a: "Any Mac running macOS 14 (Sonoma) or newer. Apple Silicon and Intel both supported." },
    { q: "Will it slow down my Mac?", a: "No. The app is about 6 MB and idle most of the time — it just listens for clipboard changes. Most people forget it's running." },
    { q: "How is this different from the built-in macOS clipboard?", a: "macOS only remembers the last thing you copied. Copy something new and the previous one is gone. Clipboard History keeps the last 1,000 items by default (up to 10,000) so you can paste any of them back with Shift + Command + V." },
    { q: "How does it compare to Paste, Maccy, or Alfred's clipboard?", a: "Honestly: it's free, open source, and tiny (~6 MB). Paste is paid and syncs across devices. Maccy is also free and open source — a great alternative if you prefer it. Alfred's clipboard comes bundled with the Powerpack. Clipboard History focuses on doing one thing well, with privacy as the default. If you need iCloud sync between Macs, pick something else." },
    { q: "Does it sync between my Macs?", a: "No, and it won't. Your clipboard often contains passwords, private messages, and tokens — sending that to a server (even Apple's) is a tradeoff we don't want to make on your behalf. Clipboard History stays on the Mac it's installed on." },
    { q: "Where is my clipboard data stored?", a: "In a single SQLite file on your Mac at ~/Library/Application Support/Clipboard History/clipboard.sqlite. Nothing is uploaded anywhere. The file is usually a few hundred kilobytes since the app stores the location of large files and screenshots, not a copy." },
    { q: "How do I uninstall Clipboard History?", a: "Quit the app from the menu bar, then drag Clipboard History from your Applications folder to the Trash. To remove your stored history too, delete the folder at ~/Library/Application Support/Clipboard History." },
    { q: "What about screenshots and copied files?", a: "Both are handled. For files you copy in Finder, the app stores the file's location, not a duplicate — so a 5 GB video costs a few kilobytes. Screenshots and images copied from the web are stored as images so you can paste them back into any app." },
    { q: "Why does it need Accessibility permission?", a: "So it can paste for you when you press Return on a clip. macOS requires Accessibility access for any app to send keystrokes to another app. If you decline, the clip still lands on your clipboard and you can paste it manually with Command + V." },
    { q: "How do updates work?", a: "The app is signed and notarized by Apple, so you won't see the scary \"unidentified developer\" warning. Updates are checked in the background and verified by Apple before they install. You can also check manually from the menu bar." },
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
            <li className="download-meta-item" data-tone="green"><span className="dm-icon" aria-hidden="true"><Icon.download/></span> ~6 MB download</li>
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
