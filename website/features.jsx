/* global React, Icon */

function FeatureGrid() {
  return (
    <div className="features-grid">
      {/* Big card: live overlay surface */}
      <div className="feature-card span-8">
        <div className="visual">
          <FeatureSearchDemo/>
        </div>
        <div className="feature-icon"><Icon.search/></div>
        <h3>Find anything you've ever copied</h3>
        <p>Type a word or two and the matching clip jumps to the top — even something you copied last week. It searches inside the text, links, and filenames. Try "invoice", "Airbnb", or your friend's name. It's instant.</p>
      </div>

      <div className="feature-card span-4">
        <div className="visual">
          <ShortcutVisual/>
        </div>
        <div className="feature-icon"><Icon.bolt/></div>
        <h3>One shortcut, anywhere</h3>
        <p>Press <span className="kbd">⇧</span> <span className="kbd">⌘</span> <span className="kbd">V</span> in any app. Pick what you want with the arrow keys. Hit Return. It pastes right where you were typing.</p>
      </div>

      <div className="feature-card span-4">
        <div className="visual">
          <DedupVisual/>
        </div>
        <div className="feature-icon"><Icon.sparkle/></div>
        <h3>No clutter</h3>
        <p>Copy the same thing twice in a row? It doesn't make a duplicate. Your list stays clean and easy to scan.</p>
      </div>

      <div className="feature-card span-4">
        <div className="visual">
          <KindsVisual/>
        </div>
        <div className="feature-icon"><Icon.clipboard/></div>
        <h3>Everything you copy</h3>
        <p>Plain text, formatted text, links, photos, screenshots, and files. Even a whole folder of files. It all comes back.</p>
      </div>

      <div className="feature-card span-4">
        <div className="visual">
          <GroupsVisual/>
        </div>
        <div className="feature-icon"><Icon.folder/></div>
        <h3>Save your favorites</h3>
        <p>Star the clips you reuse — your address, your bank details, that one Slack emoji. Or sort related clips into named groups. They never get cleaned up.</p>
      </div>
    </div>
  );
}

function FeatureSearchDemo() {
  const [phase, setPhase] = React.useState(0);
  // 0: empty, 1: typing 'sup', 2: typing 'supabase'
  React.useEffect(() => {
    const seq = [600, 1400, 2400, 3800];
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
      <div className="sv-anywhere">in any app</div>
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
  // Stack of real-looking captured items, one per kind
  const items = [
    { c: "url",   i: <Icon.link/>,  label: "URL",        text: "github.com/anthropics/anthropic-sdk" },
    { c: "image", i: <Icon.image/>, label: "Image",      text: "Screenshot 2026-05-04.png" },
    { c: "code",  i: <Icon.code/>,  label: "Code",       text: "new Anthropic({ apiKey })", mono: true },
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
    { text: "claude_api_key=sk-ant-…",     kind: "code", icon: <Icon.code/>, mono: true },
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

function BeforeAfterDemo() {
  // Animated demo: two parallel "Mac" mini-screens, one without the app, one with.
  // Cycles through copying 4 items; left side shows only the most recent;
  // right side shows the full growing stack.
  const items = [
    { kind: "url",   icon: <Icon.link/>,  text: "github.com/anthropics/anthropic-cookbook" },
    { kind: "image", icon: <Icon.image/>, text: "Screenshot 2026-05-04.png" },
    { kind: "text",  icon: <Icon.text/>,  text: "Mom's address — 1247 Oak St, Berkeley CA" },
    { kind: "code",  icon: <Icon.code/>,  text: "claude_api_key=sk-ant-…" },
  ];

  const [step, setStep] = React.useState(0);
  React.useEffect(() => {
    const id = setInterval(() => setStep(s => (s + 1) % items.length), 1800);
    return () => clearInterval(id);
  }, []);

  const current = items[step];

  return (
    <div className="ba-demo">
      <div className="ba-card ba-without">
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

      <div className="ba-card ba-with">
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
