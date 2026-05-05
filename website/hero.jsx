/* global React, Icon */
const { useState: useStateH, useEffect: useEffectH, useRef: useRefH } = React;

function HeroOverlay({ variant = "default" }) {
  // The animated overlay panel — the star of the hero.
  const [selected, setSelected] = useStateH(0);

  useEffectH(() => {
    const id = setInterval(() => {
      setSelected((s) => (s + 1) % 5);
    }, 2200);
    return () => clearInterval(id);
  }, []);

  const entries = [
    { kind: "url",   icon: <Icon.link/>,  title: "https://github.com/gug007/clipboard-history/releases/tag/v1.2.0", sub: "Safari · github.com", time: "now",   pinned: false, tag: null },
    { kind: "code",  icon: <Icon.code/>,  title: "useEffect(() => { const id = setInterval(tick, 1000); return () => clearInterval(id); }, [])", sub: "VS Code · App.tsx", time: "2m",  pinned: true,  tag: "Snippets" },
    { kind: "text",  icon: <Icon.text/>,  title: "Quick reminder — perf budget for ⇧⌘V → first paint is 80ms. Keep the panel pre-warmed.", sub: "Notes",       time: "12m", pinned: false, tag: null, body: true },
    { kind: "image", icon: <Icon.image/>, title: "Screenshot 2026-05-04 at 14.22.png", sub: "1482 × 920 · PNG · 412 KB", time: "1h", pinned: false, tag: null, thumb: "screenshots/03-current.jpg" },
    { kind: "file",  icon: <Icon.doc/>,   title: "Q2-launch-deck.key", sub: "~/Documents · 2.4 GB", time: "3h", pinned: false, tag: "Launch" },
  ];

  return (
    <div className="overlay" role="dialog" aria-label="Clipboard History overlay">
      <div className="overlay-search">
        <Icon.search/>
        <input readOnly value="" placeholder="Search clipboard history…" tabIndex={-1}/>
      </div>
      <div className="overlay-tabs">
        <button className="tab-pill active">All</button>
        <button className="tab-pill"><Icon.starOutline/> Favorites</button>
        <button className="tab-pill">Snippets</button>
        <button className="tab-pill">Launch</button>
        <button className="tab-pill" style={{color:"var(--text-3)"}}>+</button>
      </div>
      <div className="overlay-list">
        {entries.map((e, i) => (
          <div key={i} className={"entry " + (i === selected ? "selected" : "")}>
            <div className={"entry-icon " + e.kind + (e.thumb ? " has-thumb" : "")}>
              {e.thumb ? <img src={e.thumb} alt="" loading="lazy"/> : e.icon}
            </div>
            <div className="entry-body">
              <div className={"entry-title" + (e.body ? " body-text" : "")}>{e.title}</div>
              <div className="entry-sub">
                <span>{e.sub}</span>
                {e.tag && <span className="entry-tag">{e.tag}</span>}
              </div>
            </div>
            {e.pinned && <span className="star"><Icon.star/></span>}
            <span className="entry-time">{e.time}</span>
          </div>
        ))}
      </div>
      <div className="overlay-foot">
        <span className="kbd-hint"><span className="kbd">↑↓</span> navigate</span>
        <span className="kbd-hint"><span className="kbd">⏎</span> paste</span>
        <span className="kbd-hint"><span className="kbd">⌘D</span> favorite</span>
        <span className="kbd-hint"><span className="kbd">⎋</span> close</span>
        <span className="spacer"/>
        <span style={{fontVariantNumeric:"tabular-nums"}}>5 items</span>
      </div>
    </div>
  );
}

function DesktopMock() {
  return (
    <div className="desktop">
      <div className="menubar">
        <div className="menubar-l">
          <span className="apple"></span>
          <b>Clipboard History</b>
          <span style={{opacity:0.7}}>File</span>
          <span style={{opacity:0.7}}>Edit</span>
          <span style={{opacity:0.7}}>View</span>
          <span style={{opacity:0.7}}>Window</span>
          <span style={{opacity:0.7}}>Help</span>
        </div>
        <div className="menubar-r">
          <span className="clip-icon"><Icon.clipboard/></span>
          <span style={{opacity:0.7}}>🔋 87%</span>
          <span style={{opacity:0.7}}>📶</span>
          <span>Mon 14:22</span>
        </div>
      </div>
      <div className="window">
        <div className="window-chrome">
          <div className="traffic"><span className="r"/><span className="y"/><span className="g"/></div>
          <div className="window-title">app.tsx — clipboard-history</div>
          <div style={{width: 50}}/>
        </div>
        <div className="window-body">
          <div className="placeholder-line med"/>
          <div className="placeholder-line short"/>
          <div className="placeholder-line"/>
          <div className="placeholder-line short"/>
          <div className="placeholder-line med"/>
          <div className="placeholder-line"/>
          <div className="placeholder-line short"/>
          <div className="placeholder-line med"/>
          <div className="placeholder-line"/>
          <div className="placeholder-line short"/>
          <div className="placeholder-line med"/>
        </div>
      </div>
      <HeroOverlay/>
    </div>
  );
}

window.HeroOverlay = HeroOverlay;
window.DesktopMock = DesktopMock;
