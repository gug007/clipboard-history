/* global React, Icon, useDownloadUrl */

const APP_VERSION = "0.0.21";

// Visibility is owned by interactions-designer (`useStickyBarReveal` in
// app.jsx). They observe `.hero` and toggle `.is-visible` on this element.
// We just render the structure and styles.
function StickyDownloadBar() {
  const downloadUrl = useDownloadUrl();
  return (
    <div
      className="sticky-download-bar"
      data-component="sticky-download-bar"
      role="region"
      aria-label="Download"
    >
      <div className="sticky-dl-inner">
        <div className="sticky-dl-text">
          <span className="sticky-dl-title">Clipboard History</span>
          <span className="sticky-dl-meta">Free · v{APP_VERSION} · macOS 14+</span>
        </div>
        <a
          href={downloadUrl}
          className="btn btn-primary sticky-dl-cta"
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
