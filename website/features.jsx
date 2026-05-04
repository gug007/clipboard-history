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
  return (
    <div style={{height:"100%", display:"grid", placeItems:"center"}}>
      <div style={{display:"flex", gap: 10, alignItems:"center"}}>
        <span className="key-cap" style={{fontSize: 22, padding: "14px 18px", minWidth: 56, height: 56, borderRadius: 10}}>⇧</span>
        <span className="key-cap" style={{fontSize: 22, padding: "14px 18px", minWidth: 56, height: 56, borderRadius: 10}}>⌘</span>
        <span className="key-cap" style={{fontSize: 22, padding: "14px 18px", minWidth: 56, height: 56, borderRadius: 10}}>V</span>
      </div>
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
  const kinds = [
    { c: "url",   i: <Icon.link/>,  label: "URL" },
    { c: "text",  i: <Icon.text/>,  label: "Text" },
    { c: "code",  i: <Icon.code/>,  label: "Code" },
    { c: "image", i: <Icon.image/>, label: "Image" },
    { c: "file",  i: <Icon.doc/>,   label: "File" },
    { c: "url",   i: <Icon.link/>,  label: "URL" },
  ];
  return (
    <div style={{display:"grid", gridTemplateColumns:"repeat(3,1fr)", gap: 14, padding: 24, height:"100%", alignContent:"center"}}>
      {kinds.map((k, i) => (
        <div key={i} style={{display:"flex", flexDirection:"column", alignItems:"center", gap: 6}}>
          <div className={"entry-icon " + k.c} style={{width: 38, height: 38}}>{k.i}</div>
          <span style={{fontSize: 10, color: "var(--text-3)", fontWeight: 500}}>{k.label}</span>
        </div>
      ))}
    </div>
  );
}

function GroupsVisual() {
  return (
    <div style={{padding: 24, height:"100%", display:"flex", alignItems:"center", justifyContent:"center"}}>
      <div style={{display:"flex", flexWrap:"wrap", gap: 8, width:"100%", justifyContent:"center"}}>
        <span className="tab-pill active" style={{fontSize: 12, padding: "6px 12px"}}>All</span>
        <span className="tab-pill" style={{fontSize: 12, padding: "6px 12px", background:"var(--hairline)", color: "var(--text)"}}><Icon.starOutline style={{width:10,height:10}}/> Favorites</span>
        <span className="tab-pill" style={{fontSize: 12, padding: "6px 12px", background:"var(--hairline)", color: "var(--text)"}}>Snippets</span>
        <span className="tab-pill" style={{fontSize: 12, padding: "6px 12px", background:"var(--hairline)", color: "var(--text)"}}>Launch</span>
        <span className="tab-pill" style={{fontSize: 12, padding: "6px 12px", background:"var(--hairline)", color: "var(--text)"}}>Onboarding</span>
        <span className="tab-pill" style={{fontSize: 12, padding: "6px 12px", color:"var(--text-3)"}}>+</span>
      </div>
    </div>
  );
}

window.FeatureGrid = FeatureGrid;
