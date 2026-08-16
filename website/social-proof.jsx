/* global React, Icon */

const GITHUB_REPO = "gug007/clipboard-history";
function OpenSourcePill() {
  return (
    <a
      className="sp-pill sp-pill-stars"
      href={`https://github.com/${GITHUB_REPO}`}
      title="Free and open source under the MIT License"
    >
      <span className="sp-pill-icon"><Icon.github/></span>
      <span className="sp-pill-label">Free &amp; open source</span>
    </a>
  );
}

function TrustPill({ icon, label, title }) {
  return (
    <span className="sp-pill sp-pill-static" title={title || label}>
      <span className="sp-pill-icon">{icon}</span>
      <span className="sp-pill-label">{label}</span>
    </span>
  );
}

function SocialProof({ variant = "hero" }) {
  return (
    <div className={"social-proof social-proof-" + variant} role="group" aria-label="Trust and requirements">
      <OpenSourcePill/>
      <TrustPill
        icon={<Icon.shield/>}
        label="Apple-notarized"
        title="Signed and notarized by Apple — opens without warnings"
      />
      <TrustPill
        icon={<Icon.lock/>}
        label="No cloud sync"
        title="Your clipboard history stays on your Mac; the app connects only to check for updates"
      />
    </div>
  );
}

window.SocialProof = SocialProof;
window.OpenSourcePill = OpenSourcePill;
