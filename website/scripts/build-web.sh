#!/usr/bin/env bash
# Bundles React + all .jsx files into website/dist/app.js.
# Replaces the runtime-Babel + UMD-React loader with a single prebuilt script.
#
# Usage: ./scripts/build-web.sh
# Requires: npx (Node), network access on first run to pull esbuild + react.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BUILD="$ROOT/.build-web"
DIST="$ROOT/dist"

rm -rf "$BUILD"
mkdir -p "$BUILD" "$DIST"

# Tiny package.json so npm can resolve react/react-dom by name.
cat > "$BUILD/package.json" <<'JSON'
{
  "name": "clipboard-history-web-build",
  "private": true,
  "version": "0.0.0",
  "dependencies": {
    "react": "18.3.1",
    "react-dom": "18.3.1"
  }
}
JSON

# Install React + ReactDOM into the throwaway build dir.
( cd "$BUILD" && npm install --no-audit --no-fund --silent )

# JSX entrypoint: expose React/ReactDOM as window globals so the existing
# /* global React, ReactDOM */ source files still work unchanged.
cat > "$BUILD/entry.jsx" <<'JS'
import * as React from "react";
import * as ReactDOM from "react-dom/client";
window.React = React;
window.ReactDOM = ReactDOM;
JS

# Concatenate the prototype .jsx files in dependency order. Order matters:
# every file before app.jsx assigns to window.* (Icon, useDownloadUrl,
# HeroOverlay, etc.) and app.jsx is the entrypoint that calls
# ReactDOM.createRoot and reads those globals.
SOURCES=(
  "icons.jsx"
  "download.jsx"
  "tweaks-panel.jsx"
  "hero.jsx"
  "features.jsx"
  "sections.jsx"
  "social-proof.jsx"
  "sticky-bar.jsx"
  "app.jsx"
)

CONCAT="$BUILD/sources.jsx"
: > "$CONCAT"
# Each source ran as its own <script> in the old setup, so each had its own
# scope for `const { useState } = React`. Wrap each file in an IIFE on
# concatenation so duplicate top-level `const`s don't collide. Components
# survive across IIFEs because they're explicitly published to window.* at the
# bottom of each file. The final entrypoint (app.jsx) is left unwrapped so its
# top-level `ReactDOM.createRoot(...)` runs as the bundle's last statement.
LAST_INDEX=$(( ${#SOURCES[@]} - 1 ))
for i in "${!SOURCES[@]}"; do
  f="${SOURCES[$i]}"
  printf '\n// ── %s ──────────────────────────────────────────────\n' "$f" >> "$CONCAT"
  if [ "$i" -eq "$LAST_INDEX" ]; then
    cat "$ROOT/$f" >> "$CONCAT"
  else
    printf '(function () {\n' >> "$CONCAT"
    cat "$ROOT/$f" >> "$CONCAT"
    printf '\n})();\n' >> "$CONCAT"
  fi
done

# Final bundle = entry (sets window.React/ReactDOM) + concatenated sources.
cat "$BUILD/entry.jsx" "$CONCAT" > "$BUILD/bundle.jsx"

# Bundle with esbuild. JSX classic-runtime so React.createElement is called
# against window.React, matching how the original CDN+Babel setup behaved.
npx --yes --package=esbuild@0.28.0 esbuild "$BUILD/bundle.jsx" \
  --bundle \
  --minify \
  --target=es2020 \
  --jsx=transform \
  --jsx-factory=React.createElement \
  --jsx-fragment=React.Fragment \
  --loader:.jsx=jsx \
  --define:process.env.NODE_ENV='"production"' \
  --outfile="$DIST/app.js" \
  --legal-comments=none

SIZE=$(wc -c < "$DIST/app.js" | tr -d ' ')
GZIP=$(gzip -c "$DIST/app.js" | wc -c | tr -d ' ')
echo "built dist/app.js — ${SIZE} bytes (${GZIP} bytes gzipped)"

# Cleanup intermediate build artifacts.
rm -rf "$BUILD"
