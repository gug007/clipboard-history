/* global React, Icon */

function PrivacySection() {
  const points = [
    {
      icon: <Icon.database/>,
      title: "Stays on your Mac",
      body: <>Your clipboard history never leaves your computer. No account. No uploads. No telemetry.</>,
    },
    {
      icon: <Icon.lock/>,
      title: "Skips password managers",
      body: <>Anything you copy from 1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain, or LastPass is ignored. Add more apps in Settings.</>,
    },
    {
      icon: <Icon.shield/>,
      title: "Pauses for password fields",
      body: <>Recording stops automatically when you're typing in a password box or the Mac lock screen.</>,
    },
    {
      icon: <Icon.cloud/>,
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
    <section className="privacy">
      <div className="container">
        <div className="section-eyebrow">Privacy</div>
        <h2 className="section-title">Your clipboard, yours alone.</h2>
        <p className="section-lede">
          Your clipboard has private things in it — passwords half-typed, an address, a card number. The app treats it that way.
        </p>

        <div className="privacy-grid">
          <div className="privacy-points">
            {points.map((p, i) => (
              <div key={i} className="privacy-point">
                <div className="pp-icon">{p.icon}</div>
                <div>
                  <h4>{p.title}</h4>
                  <p>{p.body}</p>
                </div>
              </div>
            ))}
          </div>
          <div>
            <div className="skip-card">
              <div className="skip-card-head">
                <Icon.shield/> Password managers it ignores from day one
              </div>
              <div className="skip-grid">
                {skipped.map((a, i) => (
                  <div key={i} className="skip-chip">
                    <div className="app-icon" style={{background: a.color}}>{a.letter}</div>
                    <span>{a.name}</span>
                  </div>
                ))}
              </div>
              <div className="skip-card-foot">
                Add or remove any app from Settings.
              </div>
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
    <section>
      <div className="container">
        <div className="section-eyebrow">Keyboard shortcuts</div>
        <h2 className="section-title">Built for fast hands.</h2>
        <p className="section-lede">
          You never have to touch the mouse.
        </p>
        <div className="cheatsheet">
          <div className="shortcut-grid">
            {shortcuts.map((s, i) => (
              <div key={i} className="shortcut-row">
                <span className="label">{s.label}</span>
                <span className="keys">
                  {s.keys.map((key, j) => (
                    <React.Fragment key={j}>
                      {j > 0 && <span className="plus">+</span>}
                      <span className={"key-cap" + (key.w ? " wide" : "")}>{key.k}</span>
                    </React.Fragment>
                  ))}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

function FAQSection() {
  const faqs = [
    { q: "Is it really free?", a: "Yes. Free, open source, no account, no trial. The code is on GitHub if you want to look at it." },
    { q: "Will it record my passwords?", a: "No. The app skips anything copied from 1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain Access, and LastPass — and pauses recording when you're typing in a password field." },
    { q: "Which Macs work with it?", a: "Any Mac running macOS 14 (Sonoma) or newer. Apple Silicon and Intel both supported." },
    { q: "Will it slow down my Mac?", a: "No. The app is tiny (~6 MB) and idle most of the time. Most people forget it's running." },
  ];

  return (
    <section>
      <div className="container" style={{maxWidth: 820}}>
        <div className="section-eyebrow">Common questions</div>
        <h2 className="section-title">Questions, answered.</h2>
        <div className="faq-list" style={{marginTop: 40}}>
          {faqs.map((f, i) => (
            <details key={i} className="faq-item">
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
    <section className="download" id="download">
      <div className="container">
        <div className="download-card">
          <h2>Stop losing what you copy.</h2>
          <p>Free forever. Works offline. Just download and try it.</p>
          <div className="hero-actions">
            <a href="https://github.com/gug007/clipboard-history/releases" className="btn btn-primary btn-lg">
              <Icon.apple/> Download free for Mac
            </a>
            <a href="https://github.com/gug007/clipboard-history" className="btn btn-ghost btn-lg">
              <Icon.github/> View on GitHub
            </a>
          </div>
          <div className="download-meta">
            <span className="download-meta-item"><Icon.check/> Apple Silicon and Intel</span>
            <span className="download-meta-item"><Icon.check/> Approved by Apple</span>
            <span className="download-meta-item"><Icon.check/> macOS 14 or later</span>
            <span className="download-meta-item"><Icon.check/> ~6 MB</span>
          </div>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="foot">
      <div className="container foot-inner">
        <div>© 2026 Clipboard History · MIT License</div>
        <div className="foot-links">
          <a href="https://github.com/gug007/clipboard-history">GitHub</a>
          <a href="https://github.com/gug007/clipboard-history/releases">Releases</a>
          <a href="https://github.com/gug007/clipboard-history/blob/main/README.md">Docs</a>
          <a href="#privacy">Privacy</a>
        </div>
      </div>
    </footer>
  );
}

window.PrivacySection = PrivacySection;
window.CheatsheetSection = CheatsheetSection;
window.FAQSection = FAQSection;
window.DownloadSection = DownloadSection;
window.Footer = Footer;
