/* global React, Icon */

function FeatureGrid() {
  return (
    <ul className="features-grid" aria-label="Features">
      {/* Big card: live overlay surface */}
      <li className="feature-card span-8" data-tone="blue">
        <div className="visual" aria-hidden="true">
          <FeatureSearchDemo/>
        </div>
        <div className="feature-icon" aria-hidden="true"><Icon.search/></div>
        <h3>Find that link from Tuesday in two keystrokes</h3>
        <p>The search field is already focused when the panel opens — just type. A word or two and the right clip jumps to the top, even one from last week. It looks inside text, links, and filenames. Try "invoice", "Airbnb", or your friend's name.</p>
      </li>

      <li className="feature-card span-4" data-tone="amber">
        <div className="visual" aria-hidden="true">
          <ShortcutVisual/>
        </div>
        <div className="feature-icon" aria-hidden="true"><Icon.bolt/></div>
        <h3>One shortcut, every app</h3>
        <p>Press <span className="kbd-combo" role="img" aria-label="Shift Command V"><span className="kbd" aria-hidden="true">⇧</span> <span className="kbd" aria-hidden="true">⌘</span> <span className="kbd" aria-hidden="true">V</span></span> wherever you are — even in a fullscreen app. Arrow keys to pick, Return to paste, and the cursor never leaves where you were typing. Not your shortcut? Record your own in Settings.</p>
      </li>

      <li className="feature-card span-4" data-tone="teal">
        <div className="visual" aria-hidden="true">
          <KindsVisual/>
        </div>
        <div className="feature-icon" aria-hidden="true"><Icon.clipboard/></div>
        <h3>Text, links, files — even whole folders</h3>
        <p>Everything you copy as text, plus files and folders straight from Finder — with thumbnails, a click-to-peek preview, and <span className="kbd" aria-hidden="true">⌘R</span> to reveal the original. Files paste back as real files, not names.</p>
      </li>

      <li className="feature-card span-4" data-tone="pink">
        <div className="visual" aria-hidden="true">
          <GroupsVisual/>
        </div>
        <div className="feature-icon" aria-hidden="true"><Icon.star/></div>
        <h3>Star the clips you reach for daily</h3>
        <p>Your address, your IBAN, that one Slack emoji — star them with <span className="kbd" aria-hidden="true">⌘D</span> or sort them into named group tabs (a clip can live in several). Starred and grouped clips are never cleaned up.</p>
      </li>

      <li className="feature-card span-4" data-tone="purple">
        <div className="visual" aria-hidden="true">
          <DedupVisual/>
        </div>
        <div className="feature-icon" aria-hidden="true"><Icon.sparkle/></div>
        <h3>No piles of duplicates</h3>
        <p>Copy the same thing twice in a row and the list doesn't grow — the clip you already have just moves back to the top. Your history stays clean enough to scan at a glance.</p>
      </li>

      <li className="feature-card span-4" data-tone="blue">
        <div className="visual" aria-hidden="true">
          <ScreensVisual/>
        </div>
        <div className="feature-icon" aria-hidden="true"><Icon.bolt/></div>
        <h3>Opens where you're looking</h3>
        <p>Two monitors? The panel appears on the screen you're actually using, not a random one. It floats above fullscreen apps too, and dismisses the moment you press <span className="kbd" aria-hidden="true">⎋</span> or click away.</p>
      </li>

      <li className="feature-card span-4" data-tone="amber">
        <div className="visual" aria-hidden="true">
          <ThemesVisual/>
        </div>
        <div className="feature-icon" aria-hidden="true"><Icon.moon/></div>
        <h3>Light, dark, or follow the Mac</h3>
        <p>Pick System, Light, or Dark in Settings — or tap the sun-and-moon button right inside the panel. Whatever you're working in at 2 a.m., it won't blind you.</p>
      </li>

      <li className="feature-card span-4" data-tone="teal">
        <div className="visual" aria-hidden="true">
          <MenuBarVisual/>
        </div>
        <div className="feature-icon" aria-hidden="true"><Icon.clipboard/></div>
        <h3>Lives quietly in your menu bar</h3>
        <p>No Dock icon, no windows to manage. It starts with your Mac (switch that off in Settings if you like), and one click on Pause Recording keeps moments off the record until you resume.</p>
      </li>
    </ul>
  );
}

// WCAG 2.2.2: skip auto-rotating intervals when the user prefers reduced motion.
function prefersReducedMotionF() {
  return typeof window !== "undefined" &&
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function FeatureSearchDemo() {
  const [phase, setPhase] = React.useState(0);
  // 0: empty, 1: typing 'sup', 2: typing 'supabase'
  React.useEffect(() => {
    if (prefersReducedMotionF()) return;
    let i = 0;
    const tick = () => {
      i = (i + 1) % 4;
      setPhase(i);
    };
    const id = setInterval(tick, 1500);
    return () => clearInterval(id);
  }, []);

  const queries = ["", "su", "supa", "supabase"];
  const q = queries[phase];

  const allRows = [
    { kind: "url", icon: <Icon.link/>, text: "https://supabase.com/dashboard/project/abcd-prod", meta: "2m" },
    { kind: "code", icon: <Icon.code/>, text: "createClient(SUPABASE_URL, SUPABASE_ANON_KEY)", meta: "14m" },
    { kind: "text", icon: <Icon.text/>, text: "Supabase migration completed — schema_v4 active", meta: "1h" },
    { kind: "file", icon: <Icon.doc/>, text: "supabase-cli-config.toml", meta: "3h" },
  ];

  const visible = q ? allRows.filter(r => r.text.toLowerCase().includes(q)) : allRows;

  const highlight = (text) => {
    if (!q) return text;
    const idx = text.toLowerCase().indexOf(q);
    if (idx === -1) return text;
    return <>{text.slice(0,idx)}<mark>{text.slice(idx, idx+q.length)}</mark>{text.slice(idx+q.length)}</>;
  };

  return (
    <div className="search-demo">
      <div className="search-bar">
        <Icon.search/>
        <span className="typed">{q}<span className="caret"/></span>
      </div>
      <div className="search-results">
        {visible.slice(0, 4).map((r, i) => (
          <div key={i} className="search-row">
            <span className="icon-sm">{r.icon}</span>
            <span style={{whiteSpace:"nowrap", overflow:"hidden", textOverflow:"ellipsis"}}>{highlight(r.text)}</span>
            <span className="meta">{r.meta}</span>
          </div>
        ))}
        {visible.length === 0 && (
          <div style={{padding: 24, fontSize: 11, color: "var(--text-3)", textAlign:"center"}}>No matches</div>
        )}
      </div>
    </div>
  );
}

function ShortcutVisual() {
  // Just the keys, big and confident. No app rail decoration.
  return (
    <div className="shortcut-visual">
      <div className="sv-keys">
        <span className="key-cap sv-key">⇧</span>
        <span className="key-cap sv-key">⌘</span>
        <span className="key-cap sv-key">V</span>
      </div>
      <div className="sv-anywhere">in any app — or record your own</div>
    </div>
  );
}

function DedupVisual() {
  const ix = { width: 14, height: 14, flexShrink: 0, color: "var(--text-3)" };
  const lbl = { whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", flex: 1, minWidth: 0 };
  const time = { fontSize: 10, color: "var(--text-3)", flexShrink: 0 };
  return (
    <div style={{padding: 20, height: "100%", display:"flex", alignItems:"center"}}>
      <div className="dedup-demo" style={{width:"100%"}}>
        <div className="row muted"><span className="num">1</span><Icon.text style={ix}/><span style={lbl}>Project URL</span><span style={time}>14:01</span></div>
        <div className="row"><span className="num">2</span><Icon.text style={ix}/><span style={lbl}>Meeting notes</span><span style={time}>14:08</span></div>
        <div className="row bumped"><span className="num">1</span><Icon.text style={ix}/><span style={lbl}>Project URL</span><span className="badge" style={{flexShrink: 0}}>bumped</span></div>
      </div>
    </div>
  );
}

function KindsVisual() {
  // Stack of real-looking captured items, one per kind the app records
  const items = [
    { c: "url",   i: <Icon.link/>,  label: "Link",       text: "github.com/anthropics/anthropic-sdk" },
    { c: "code",  i: <Icon.code/>,  label: "Text",       text: "new Anthropic({ apiKey })", mono: true },
    { c: "file",  i: <Icon.image/>, label: "File",       text: "Screenshot 2026-06-30.png · 412 KB" },
    { c: "file",  i: <Icon.doc/>,   label: "Folder",     text: "Mocks · 24 files" },
  ];
  return (
    <div className="kinds-visual">
      {items.map((k, i) => (
        <div key={i} className="kind-row">
          <div className={"entry-icon " + k.c} style={{width: 26, height: 26, flexShrink: 0}}>{k.i}</div>
          <div className="kind-meta">
            <div className="kind-label">{k.label}</div>
            <div className={"kind-text" + (k.mono ? " mono" : "")}>{k.text}</div>
          </div>
        </div>
      ))}
    </div>
  );
}

function GroupsVisual() {
  const folders = [
    { name: "Favorites",  icon: <Icon.starOutline/>, count: 12, active: true },
    { name: "Snippets",   icon: <Icon.code/>,        count: 8 },
    { name: "Addresses",  icon: <Icon.text/>,        count: 4 },
  ];
  const starred = [
    { text: "1247 Oak St, Berkeley CA",   kind: "text", icon: <Icon.text/> },
    { text: "DE89 3704 0044 0532 0130 00", kind: "text", icon: <Icon.text/>, mono: true },
    { text: ":shipit: 🚀",                  kind: "text", icon: <Icon.text/> },
  ];
  return (
    <div className="groups-visual">
      <div className="gv-sidebar">
        {folders.map((f, i) => (
          <div key={i} className={"gv-folder" + (f.active ? " active" : "")}>
            <span className="gv-folder-icon">{f.icon}</span>
            <span className="gv-folder-name">{f.name}</span>
            <span className="gv-folder-count">{f.count}</span>
          </div>
        ))}
      </div>
      <div className="gv-list">
        {starred.map((s, i) => (
          <div key={i} className="gv-item">
            <span className="gv-star"><Icon.star/></span>
            <span className={"gv-text" + (s.mono ? " mono" : "")}>{s.text}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function ScreensVisual() {
  // Two mini displays; the overlay panel sits on the one with the cursor.
  return (
    <div className="screens-visual">
      <div className="scv-display">
        <div className="scv-menubar"/>
      </div>
      <div className="scv-display scv-active">
        <div className="scv-menubar"/>
        <div className="scv-panel">
          <div className="scv-panel-search"/>
          <div className="scv-panel-row"/>
          <div className="scv-panel-row"/>
          <div className="scv-panel-row short"/>
        </div>
        <div className="scv-cursor" aria-hidden="true">↖</div>
      </div>
    </div>
  );
}

function ThemesVisual() {
  return (
    <div className="themes-visual">
      <div className="thv-card thv-light">
        <div className="thv-bar"/>
        <div className="thv-row"/>
        <div className="thv-row short"/>
        <span className="thv-label">Light</span>
      </div>
      <div className="thv-card thv-dark">
        <div className="thv-bar"/>
        <div className="thv-row"/>
        <div className="thv-row short"/>
        <span className="thv-label">Dark</span>
      </div>
      <div className="thv-card thv-system">
        <div className="thv-half thv-light-half">
          <div className="thv-bar"/>
          <div className="thv-row"/>
        </div>
        <div className="thv-half thv-dark-half">
          <div className="thv-bar"/>
          <div className="thv-row"/>
        </div>
        <span className="thv-label">System</span>
      </div>
    </div>
  );
}

function MenuBarVisual() {
  return (
    <div className="mbv">
      <div className="mbv-bar">
        <span className="mbv-spacer"/>
        <span className="mbv-icon active"><Icon.clipboard/></span>
        <span className="mbv-icon">📶</span>
        <span className="mbv-time">Tue 09:41</span>
      </div>
      <div className="mbv-menu">
        <div className="mbv-item"><span>Open Clipboard History</span><span className="mbv-kbd">⇧⌘V</span></div>
        <div className="mbv-item highlight"><span>Pause Recording</span></div>
        <div className="mbv-sep"/>
        <div className="mbv-item"><span>Settings…</span><span className="mbv-kbd">⌘,</span></div>
        <div className="mbv-item"><span>Check for Updates…</span></div>
      </div>
    </div>
  );
}

function BeforeAfterDemo() {
  // Animated demo: two parallel "Mac" mini-screens, one without the app, one with.
  // Cycles through copying 4 items; left side shows only the most recent;
  // right side shows the full growing stack.
  const items = [
    { kind: "url",   icon: <Icon.link/>,  text: "github.com/anthropics/anthropic-cookbook" },
    { kind: "file",  icon: <Icon.doc/>,   text: "Screenshot 2026-06-30.png" },
    { kind: "text",  icon: <Icon.text/>,  text: "Mom's address — 1247 Oak St, Berkeley CA" },
    { kind: "text",  icon: <Icon.text/>,  text: "Tracking № 1Z 999 AA1 01 2345 6784" },
  ];

  const [step, setStep] = React.useState(0);
  React.useEffect(() => {
    if (prefersReducedMotionF()) return;
    const id = setInterval(() => setStep(s => (s + 1) % items.length), 1800);
    return () => clearInterval(id);
  }, []);

  const current = items[step];

  return (
    <div className="ba-demo" role="img" aria-label="Comparison: without Clipboard History the previous clipboard items are lost; with Clipboard History they are still saved.">
      <div className="ba-card ba-without" aria-hidden="true">
        <div className="ba-head">
          <span className="ba-dot ba-dot-no"/>
          <span>Without Clipboard History</span>
        </div>
        <div className="ba-body">
          <div className="ba-current">
            <span className="ba-current-label">On your clipboard right now</span>
            <div className="ba-row ba-row-current">
              <span className={"entry-icon " + current.kind} style={{width:28, height:28, flexShrink:0}}>{current.icon}</span>
              <span className="ba-text">{current.text}</span>
            </div>
          </div>
          <div className="ba-lost">
            <span className="ba-lost-label">Earlier today</span>
            <div className="ba-lost-stack">
              {items.filter((_, i) => i !== step).map((it, i) => (
                <div key={i} className="ba-row ba-row-lost">
                  <span className={"entry-icon " + it.kind} style={{width:24, height:24, flexShrink:0, opacity:0.4}}>{it.icon}</span>
                  <span className="ba-text" style={{textDecoration:"line-through", color:"var(--text-3)"}}>{it.text}</span>
                </div>
              ))}
              <div className="ba-gone">All gone. Forever.</div>
            </div>
          </div>
        </div>
      </div>

      <div className="ba-arrow" aria-hidden="true">
        <svg viewBox="0 0 40 40" width="40" height="40"><path d="M8 20 L32 20 M22 10 L32 20 L22 30" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
      </div>

      <div className="ba-card ba-with" aria-hidden="true">
        <div className="ba-head">
          <span className="ba-dot ba-dot-yes"/>
          <span>With Clipboard History</span>
        </div>
        <div className="ba-body">
          <div className="ba-current">
            <span className="ba-current-label">On your clipboard right now</span>
            <div className="ba-row ba-row-current">
              <span className={"entry-icon " + current.kind} style={{width:28, height:28, flexShrink:0}}>{current.icon}</span>
              <span className="ba-text">{current.text}</span>
            </div>
          </div>
          <div className="ba-saved">
            <span className="ba-saved-label">
              <Icon.check/> Still there when you need them
            </span>
            <div className="ba-saved-stack">
              {items.filter((_, i) => i !== step).map((it, i) => (
                <div key={i} className="ba-row ba-row-saved">
                  <span className={"entry-icon " + it.kind} style={{width:24, height:24, flexShrink:0}}>{it.icon}</span>
                  <span className="ba-text">{it.text}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

window.FeatureGrid = FeatureGrid;
window.BeforeAfterDemo = BeforeAfterDemo;
