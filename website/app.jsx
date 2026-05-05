/* global React, ReactDOM, Icon, HeroOverlay, DesktopMock, BeforeAfterDemo, FeatureGrid, PrivacySection, StorageSection, CheatsheetSection, FAQSection, DownloadSection, Footer, useTweaks, TweaksPanel, TweakSection, TweakRadio, TweakColor */
const { useState, useEffect } = React;

function Nav({ theme, setTheme }) {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  return (
    <nav className={"nav " + (scrolled ? "scrolled" : "")}>
      <div className="container nav-inner">
        <a className="brand" href="#top">
          <span className="brand-mark"><Icon.clipboard/></span>
          <span>Clipboard History</span>
        </a>
        <div className="nav-links">
          <a href="#features">Features</a>
          <a href="#privacy">Privacy</a>
          <a href="#shortcuts">Shortcuts</a>
          <a href="#faq">FAQ</a>
          <a href="https://github.com/gug007/clipboard-history">GitHub</a>
        </div>
        <div className="nav-actions">
          <button
            className="theme-toggle"
            onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
            aria-label="Toggle theme"
            title={theme === "dark" ? "Switch to light" : "Switch to dark"}
          >
            {theme === "dark" ? <Icon.sun/> : <Icon.moon/>}
          </button>
          <a href="#download" className="btn btn-primary">
            <Icon.download/> Download
          </a>
        </div>
      </div>
    </nav>
  );
}

function Hero() {
  return (
    <header className="hero" id="top">
      <div className="container">
        <div className="eyebrow">
          <span className="dot"/>
          <span>Free for Mac · No account, no cloud</span>
        </div>
        <h1>Never lose what you <em>copy</em>.</h1>
        <p className="hero-sub">
          Clipboard History remembers everything you copy on your Mac — every link, every paragraph, every screenshot, every file. Press <span className="kbd-combo"><span className="kbd">⇧</span><span className="kbd">⌘</span><span className="kbd">V</span></span> and bring any of it back.
        </p>
        <div className="hero-actions">
          <a href="#download" className="btn btn-primary btn-lg">
            <Icon.apple/> Download free for Mac
          </a>
          <a href="https://github.com/gug007/clipboard-history" className="btn btn-ghost btn-lg">
            <Icon.github/> View on GitHub
          </a>
        </div>
        <div className="hero-meta">Works on any Mac running macOS 14 or later. No sign-up, ever.</div>
      </div>
      <div className="hero-stage">
        <DesktopMock/>
      </div>
    </header>
  );
}

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "light",
  "accent": "#0a84ff"
}/*EDITMODE-END*/;

function App() {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const theme = tweaks.theme;

  const setTheme = (t) => setTweak("theme", t);

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  useEffect(() => {
    document.documentElement.style.setProperty("--accent", tweaks.accent);
    // accent-soft derived
    const hex = tweaks.accent.replace("#","");
    const r = parseInt(hex.slice(0,2),16), g = parseInt(hex.slice(2,4),16), b = parseInt(hex.slice(4,6),16);
    document.documentElement.style.setProperty("--accent-soft", `rgba(${r},${g},${b},${theme==="dark"?0.18:0.12})`);
  }, [tweaks.accent, theme]);

  return (
    <>
      <Nav theme={theme} setTheme={setTheme}/>
      <Hero/>
      <section id="features">
        <div className="container">
          <div className="section-eyebrow">What it does</div>
          <h2 className="section-title">A second brain for your clipboard.</h2>
          <p className="section-lede">
            Every time you copy something new, the last thing is gone. Clipboard History remembers it all — quietly in the background — so you can paste any of it back, anytime.
          </p>
          <BeforeAfterDemo/>
          <FeatureGrid/>
        </div>
      </section>
      <div id="privacy"><PrivacySection/></div>
      <StorageSection/>
      <div id="shortcuts"><CheatsheetSection/></div>
      <div id="faq"><FAQSection/></div>
      <div id="download"><DownloadSection/></div>
      <Footer/>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Appearance">
          <TweakRadio
            label="Theme"
            value={tweaks.theme}
            onChange={(v) => setTweak("theme", v)}
            options={[
              { value: "light", label: "Light" },
              { value: "dark", label: "Dark" },
            ]}
          />
          <TweakColor
            label="Accent"
            value={tweaks.accent}
            onChange={(v) => setTweak("accent", v)}
            presets={["#0a84ff", "#ff375f", "#30d158", "#bf5af2", "#ff9f0a", "#5e5ce6"]}
          />
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
