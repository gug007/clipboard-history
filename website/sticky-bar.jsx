/* global React, Icon, useLatestRelease */

// Visibility is owned by `useStickyBarReveal` in app.jsx. Keep the hidden
// state out of the keyboard and accessibility trees until the bar is shown.
function StickyDownloadBar({ visible = false }) {
  const { url, version } = useLatestRelease();
  return (
    <div
      className={"sticky-download-bar" + (visible ? " is-visible" : "")}
      data-component="sticky-download-bar"
      role="region"
      aria-label="Download"
      aria-hidden={!visible}
      inert={visible ? undefined : ""}
    >
      <div className="sticky-dl-inner">
        <div className="sticky-dl-text">
          <span className="sticky-dl-title">Clipboard History</span>
          <span className="sticky-dl-meta">Free · v{version} · macOS 14+</span>
        </div>
        <a
          href={url}
          className="btn btn-primary sticky-dl-cta"
          tabIndex={visible ? 0 : -1}
          onClick={() => window.plausible && window.plausible('Download Click', { props: { source: 'sticky-bar' } })}
        >
          <span aria-hidden="true"><Icon.apple/></span>
          <span>Download</span>
        </a>
      </div>
    </div>
  );
}

window.StickyDownloadBar = StickyDownloadBar;
