/* global React */
const { useState, useEffect, useRef } = React;

// ─── Icon set ─────────────────────────────────────────────
const Icon = {
  clipboard: (p) => (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <rect x="3.5" y="3" width="9" height="11.5" rx="1.5"/>
      <path d="M6 3V2.2A1 1 0 0 1 7 1.3h2A1 1 0 0 1 10 2.2V3"/>
      <path d="M5.5 7h5M5.5 9.5h5M5.5 12h3"/>
    </svg>
  ),
  search: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><circle cx="7" cy="7" r="4.5"/><path d="m10.5 10.5 3 3"/></svg>,
  star: (p) => <svg viewBox="0 0 16 16" fill="currentColor" {...p}><path d="M8 1.6l1.83 4.06 4.42.42-3.34 2.94 1 4.34L8 11.13l-3.91 2.23 1-4.34L1.75 6.08l4.42-.42z"/></svg>,
  starOutline: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinejoin="round" {...p}><path d="M8 1.6l1.83 4.06 4.42.42-3.34 2.94 1 4.34L8 11.13l-3.91 2.23 1-4.34L1.75 6.08l4.42-.42z"/></svg>,
  link: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M6.5 9.5a2.5 2.5 0 0 0 3.54 0l2-2a2.5 2.5 0 0 0-3.54-3.54l-.5.5"/><path d="M9.5 6.5a2.5 2.5 0 0 0-3.54 0l-2 2a2.5 2.5 0 0 0 3.54 3.54l.5-.5"/></svg>,
  doc: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M9.5 2H4.5A1.5 1.5 0 0 0 3 3.5v9A1.5 1.5 0 0 0 4.5 14h7a1.5 1.5 0 0 0 1.5-1.5V5.5L9.5 2z"/><path d="M9.5 2v3.5H13"/></svg>,
  image: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><rect x="2.5" y="3" width="11" height="10" rx="1.5"/><circle cx="6" cy="6.5" r="1"/><path d="m13 11-3.5-3.5L4 13"/></svg>,
  text: (p) => <svg viewBox="0 0 16 16" fill="currentColor" {...p}><rect x="3" y="3.4" width="10" height="1.4" rx="0.6"/><rect x="3" y="6.4" width="8" height="1.4" rx="0.6"/><rect x="3" y="9.4" width="10" height="1.4" rx="0.6"/><rect x="3" y="12.4" width="6" height="1.4" rx="0.6"/></svg>,
  code: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="m6 4-4 4 4 4M10 4l4 4-4 4"/></svg>,
  shield: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M8 1.5 2.5 3.5v4c0 3.5 2.4 6.3 5.5 7 3.1-.7 5.5-3.5 5.5-7v-4z"/><path d="m6 8 1.5 1.5L10.5 6.5"/></svg>,
  lock: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><rect x="3.5" y="7" width="9" height="6.5" rx="1.5"/><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2"/></svg>,
  database: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><ellipse cx="8" cy="3.5" rx="5" ry="1.5"/><path d="M3 3.5v9c0 .8 2.2 1.5 5 1.5s5-.7 5-1.5v-9"/><path d="M3 8c0 .8 2.2 1.5 5 1.5s5-.7 5-1.5"/></svg>,
  cloud: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M11.3 11.5H4.7a2.7 2.7 0 0 1-.4-5.4A4 4 0 0 1 12 6.5a2.5 2.5 0 0 1-.7 5z"/></svg>,
  bolt: (p) => <svg viewBox="0 0 16 16" fill="currentColor" {...p}><path d="M9 1 3 9h4l-1 6 6-8H8z"/></svg>,
  pause: (p) => <svg viewBox="0 0 16 16" fill="currentColor" {...p}><rect x="4" y="3" width="3" height="10" rx="1"/><rect x="9" y="3" width="3" height="10" rx="1"/></svg>,
  folder: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M2 5a1.5 1.5 0 0 1 1.5-1.5h3l1.5 1.5h4.5A1.5 1.5 0 0 1 14 6.5v5A1.5 1.5 0 0 1 12.5 13h-9A1.5 1.5 0 0 1 2 11.5z"/></svg>,
  download: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M8 2v9M4.5 7.5 8 11l3.5-3.5M3 13.5h10"/></svg>,
  github: (p) => <svg viewBox="0 0 16 16" fill="currentColor" {...p}><path fillRule="evenodd" d="M8 0a8 8 0 0 0-2.53 15.59c.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.42 7.42 0 0 1 4 0c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8 8 0 0 0 8 0z" clipRule="evenodd"/></svg>,
  apple: (p) => <svg viewBox="0 0 16 16" fill="currentColor" {...p}><path d="M11.46 8.4c-.02-1.86 1.52-2.76 1.59-2.8-.87-1.26-2.21-1.44-2.69-1.45-1.14-.12-2.23.67-2.81.67-.59 0-1.48-.66-2.43-.64-1.25.02-2.4.72-3.04 1.84-1.3 2.25-.33 5.57.93 7.4.62.89 1.36 1.89 2.31 1.85.93-.04 1.28-.6 2.4-.6s1.44.6 2.42.58c1-.02 1.63-.91 2.24-1.8.71-1.04.99-2.04 1.01-2.1-.02-.01-1.94-.74-1.96-2.95zM9.62 2.92c.51-.62.86-1.49.77-2.35-.74.03-1.64.49-2.17 1.11-.47.55-.89 1.43-.78 2.27.83.07 1.66-.42 2.18-1.03z"/></svg>,
  sparkle: (p) => <svg viewBox="0 0 16 16" fill="currentColor" {...p}><path d="M8 1l1.5 4.5L14 7l-4.5 1.5L8 13l-1.5-4.5L2 7l4.5-1.5z"/></svg>,
  check: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="m3.5 8.5 3 3 6-7"/></svg>,
  sun: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" {...p}><circle cx="8" cy="8" r="3"/><path d="M8 1.5v1.5M8 13v1.5M2.5 8H1m14 0h-1.5M3.6 3.6l1 1m6.7 6.7 1 1M3.6 12.4l1-1m6.7-6.7 1-1"/></svg>,
  moon: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M13.5 9.5A6 6 0 0 1 6.5 2.5a5.5 5.5 0 1 0 7 7z"/></svg>,
  arrowRight: (p) => <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M3.5 8h9M9 4.5 12.5 8 9 11.5"/></svg>,
};

window.Icon = Icon;
