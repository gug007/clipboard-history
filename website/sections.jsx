/* global React, Icon */

function PrivacySection() {
  const points = [
    {
      icon: <Icon.database/>,
      title: "Stays on your Mac. Always.",
      body: <>Your clipboard history never leaves your computer. There's no account to make. Nothing gets uploaded to the cloud. We don't see any of it — ever.</>,
    },
    {
      icon: <Icon.lock/>,
      title: "Ignores your password manager",
      body: <>When you copy a password from 1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain Access, or LastPass, the app pretends it didn't see it. You can add other apps to the list too.</>,
    },
    {
      icon: <Icon.shield/>,
      title: "Doesn't watch password fields",
      body: <>Whenever you're typing into a password box, a sudo prompt, or the Mac lock screen, recording pauses automatically. Anything an app marks as "don't save" is also skipped.</>,
    },
    {
      icon: <Icon.cloud/>,
      title: "Safe to install",
      body: <>The app is signed and approved by Apple, so macOS opens it without warnings. Updates are checked over a secure connection and verified before installing.</>,
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
        <div className="privacy-top">
          <div className="privacy-copy">
            <div className="section-eyebrow">Privacy</div>
            <h2 className="section-title">Your clipboard.<br/>Yours alone.</h2>
            <p className="section-lede">
              Your clipboard has private things in it — passwords half-typed, a friend's address, a credit card number. We treat it that way.
            </p>
            <ul className="privacy-checks">
              <li><Icon.check/> No cloud uploads</li>
              <li><Icon.check/> No account needed</li>
              <li><Icon.check/> No analytics or tracking</li>
              <li><Icon.check/> Open and inspectable</li>
            </ul>
          </div>

          <div className="privacy-flow">
            <div className="pf-row pf-row-source">
              <div className="pf-icon"><Icon.clipboard/></div>
              <div className="pf-row-text">
                <div className="pf-row-title">You copy something</div>
                <div className="pf-row-sub">Text, image, code, file — anything.</div>
              </div>
            </div>

            <div className="pf-arrow" aria-hidden="true">
              <svg viewBox="0 0 24 40" preserveAspectRatio="none">
                <path d="M12 0 L12 32" stroke="currentColor" strokeWidth="1.5" strokeDasharray="3 4"/>
                <path d="M6 28 L12 40 L18 28" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>

            <div className="pf-mac">
              <div className="pf-mac-screen">
                <div className="pf-mac-bezel">
                  <div className="pf-mac-window">
                    <div className="pf-mac-bar">
                      <span/><span/><span/>
                    </div>
                    <div className="pf-mac-app">
                      <div className="pf-mac-clip">
                        <div className="pf-mac-clip-icon" style={{background:"#0aa658"}}>{<Icon.link/>}</div>
                        <div className="pf-mac-clip-text">github.com/anthropics/…</div>
                      </div>
                      <div className="pf-mac-clip">
                        <div className="pf-mac-clip-icon" style={{background:"#7a5af8"}}>{<Icon.image/>}</div>
                        <div className="pf-mac-clip-text">Screenshot 2026-05-04.png</div>
                      </div>
                      <div className="pf-mac-clip">
                        <div className="pf-mac-clip-icon" style={{background:"#f5a623"}}>{<Icon.text/>}</div>
                        <div className="pf-mac-clip-text">1247 Oak St, Berkeley CA</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="pf-mac-hinge"/>
              <div className="pf-mac-base"/>
            </div>

            <div className="pf-deny">
              <div className="pf-deny-item">
                <span className="pf-deny-x" aria-hidden="true"/>
                <Icon.cloud/>
                <span>Never the cloud</span>
              </div>
              <div className="pf-deny-item">
                <span className="pf-deny-x" aria-hidden="true"/>
                <Icon.shield/>
                <span>Never tracked</span>
              </div>
              <div className="pf-deny-item">
                <span className="pf-deny-x" aria-hidden="true"/>
                <Icon.database/>
                <span>Never collected</span>
              </div>
            </div>
          </div>
        </div>

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

function StorageSection() {
  return (
    <section>
      <div className="container">
        <div className="section-eyebrow">How it works</div>
        <h2 className="section-title">It barely takes any space.</h2>
        <p className="section-lede">
          Even after months of use, Clipboard History uses a tiny amount of disk space — because it's clever about what it stores.
        </p>
        <div className="duo-grid">
          <div className="duo-card">
            <h3>Copy a 5 GB file? Costs almost nothing.</h3>
            <p>When you copy a file or photo, the app remembers <em>where</em> it lives, not the file itself. So a huge file in your history takes just a few kilobytes — like saving a bookmark, not a copy.</p>
            <div className="size-bar">
              <div className="icon-lg"><Icon.doc/></div>
              <div className="stack">
                <b>Q2-launch-deck.key</b>
                <span>~/Documents — 2.4 GB on disk</span>
              </div>
              <div className="bytes">3.1 KB</div>
            </div>
            <div className="size-bar">
              <div className="icon-lg" style={{background:"rgba(175,82,222,0.15)", color:"#af52de"}}><Icon.image/></div>
              <div className="stack">
                <b>Screenshot.png</b>
                <span>1482 × 920 — 412 KB</span>
              </div>
              <div className="bytes">2.4 KB</div>
            </div>
          </div>
          <div className="duo-card">
            <h3>Keeps the list tidy.</h3>
            <p>Copy the same thing right after copying it? It just bumps the existing entry to the top instead of making a duplicate. By default, the app remembers your last 1,000 clips — you can crank that up to 10,000 if you want.</p>
            <div className="dedup-demo">
              <div className="row"><span className="num">1</span><span className="entry-icon url" style={{width:24, height:24}}><Icon.link/></span><span>github.com/gug007/clipboard-history</span><span style={{marginLeft:"auto", fontSize:10, color:"var(--text-3)"}}>14:01</span></div>
              <div className="row"><span className="num">2</span><span className="entry-icon text" style={{width:24, height:24}}><Icon.text/></span><span>Meeting notes — Q2 planning</span><span style={{marginLeft:"auto", fontSize:10, color:"var(--text-3)"}}>14:08</span></div>
              <div className="row"><span className="num">3</span><span className="entry-icon code" style={{width:24, height:24}}><Icon.code/></span><span>useEffect(() =&gt; {`{...}`})</span><span style={{marginLeft:"auto", fontSize:10, color:"var(--text-3)"}}>14:14</span></div>
              <div className="row bumped"><span className="num">1</span><span className="entry-icon url" style={{width:24, height:24, flexShrink:0}}><Icon.link/></span><span style={{whiteSpace:"nowrap", overflow:"hidden", textOverflow:"ellipsis", flex:1, minWidth:0}}>github.com/gug007/clipboard-history</span><span className="badge">moved up</span></div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function CheatsheetSection() {
  // Each key: { k: symbol, w: optional 'wide' for word keys }
  const shortcuts = [
    { label: "Open your clipboard history",     keys: [{k:"⇧"}, {k:"⌘"}, {k:"V"}] },
    { label: "Move up or down the list",        keys: [{k:"↑"}, {k:"↓"}] },
    { label: "Paste the highlighted item",      keys: [{k:"⏎ Return", w:true}] },
    { label: "Pick the 1st–9th item directly",  keys: [{k:"⌘"}, {k:"1–9", w:true}] },
    { label: "Switch between groups",           keys: [{k:"⌥"}, {k:"1–9", w:true}] },
    { label: "Star or un-star a clip",          keys: [{k:"⌘"}, {k:"D"}] },
    { label: "Delete a clip",                   keys: [{k:"⌘"}, {k:"⌫"}] },
    { label: "Show file in Finder",             keys: [{k:"⌘"}, {k:"R"}] },
    { label: "Jump to your starred clips",      keys: [{k:"⇧"}, {k:"F"}] },
    { label: "Close the window",                keys: [{k:"⎋ Esc", w:true}] },
  ];

  return (
    <section>
      <div className="container">
        <div className="section-eyebrow">Keyboard shortcuts</div>
        <h2 className="section-title">Built for fast hands.</h2>
        <p className="section-lede">
          You never have to touch the mouse. Every action has a single key.
        </p>
        <div className="key-legend">
          <div className="key-legend-item"><span className="key-cap">⇧</span><span>Shift</span></div>
          <div className="key-legend-item"><span className="key-cap">⌘</span><span>Command</span></div>
          <div className="key-legend-item"><span className="key-cap">⌥</span><span>Option</span></div>
          <div className="key-legend-item"><span className="key-cap">⏎</span><span>Return</span></div>
          <div className="key-legend-item"><span className="key-cap">⌫</span><span>Delete</span></div>
          <div className="key-legend-item"><span className="key-cap">⎋</span><span>Esc</span></div>
        </div>
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
    { q: "Is it really free?", a: "Yes. Clipboard History is completely free. There's nothing to buy, no trial, and no account to make. The code is open source on GitHub if you want to look at it." },
    { q: "Does it work without the internet?", a: "Yes. Everything happens on your Mac. You can use it on a plane, in a tunnel, or anywhere else — it works the same." },
    { q: "Will it record my passwords?", a: "No. The app skips anything you copy from popular password managers (1Password, Bitwarden, Dashlane, KeePassXC, Apple Passwords, Keychain Access, LastPass). It also pauses recording whenever you're typing into a password field." },
    { q: "Which Macs work with it?", a: "Any Mac running macOS 14 (Sonoma) or newer. It works on both Apple Silicon (M1, M2, M3, M4) and older Intel Macs." },
    { q: "How do I open my clipboard history?", a: "Press Shift, Command, and V at the same time — you'll see a list of everything you've copied. Pick one with the arrow keys, hit Return, and it pastes. You can change the shortcut in Settings if you want." },
    { q: "Will it slow down my Mac?", a: "No. The app uses very little memory and does almost nothing when you're not using it. Most people forget it's running." },
    { q: "Can I delete things from my history?", a: "Yes. Open the list, highlight any item, and press Command + Delete. You can also clear everything from Settings." },
    { q: "What happens to old clips?", a: "By default, the app keeps your most recent 1,000 clips and quietly removes older ones. You can change this number in Settings, or save important ones with a star so they're never removed." },
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
            <span className="download-meta-item"><Icon.check/> Works on Apple Silicon and Intel</span>
            <span className="download-meta-item"><Icon.check/> Approved by Apple</span>
            <span className="download-meta-item"><Icon.check/> Needs macOS 14 or later</span>
            <span className="download-meta-item"><Icon.check/> Tiny — about 6 MB</span>
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
window.StorageSection = StorageSection;
window.CheatsheetSection = CheatsheetSection;
window.FAQSection = FAQSection;
window.DownloadSection = DownloadSection;
window.Footer = Footer;
