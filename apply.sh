#!/bin/bash
# Applies the Nord Polar Night theme to ZCode's dark mode.
# Safe to re-run: strips any previous mod block before regenerating.
# Requires: macOS, Node.js (npx). Restart ZCode afterwards.
set -euo pipefail

APP="${ZCODE_APP:-/Applications/ZCode.app}"
RES="$APP/Contents/Resources"
BACKUP_DIR="${ZCODE_BACKUP_DIR:-$HOME/.zcode/backup}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d /tmp/zcode-nord.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

command -v node > /dev/null || { echo "ERROR: node not found on PATH"; exit 1; }
command -v npx  > /dev/null || { echo "ERROR: npx not found on PATH"; exit 1; }
[ -d "$RES" ] || { echo "ERROR: ZCode not found at $APP (override with ZCODE_APP)"; exit 1; }

VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
ASAR="$RES/app.asar"

mkdir -p "$BACKUP_DIR"
if [ ! -f "$BACKUP_DIR/app.asar.v$VERSION.bak" ]; then
  cp "$ASAR" "$BACKUP_DIR/app.asar.v$VERSION.bak"
  echo "backed up original to $BACKUP_DIR/app.asar.v$VERSION.bak"
fi

echo "extracting app.asar (v$VERSION)..."
npx --yes @electron/asar@3 extract "$ASAR" "$WORK/extract"

CSS=$(grep -rl 'theme-zai-dark' "$WORK/extract/out/renderer/assets" --include='*.css' | head -1)
if [ -z "$CSS" ]; then
  echo "ERROR: theme CSS not found — app layout changed, gen-nord.js needs updating. Original untouched."
  exit 1
fi

# strip any previous mod block first so the generator never re-processes its own output
node -e '
const fs = require("fs");
const cssPath = process.argv[1];
let css = fs.readFileSync(cssPath, "utf8");
css = css.replace(/\/\* ZCODE-NORD-MOD-START[\s\S]*?ZCODE-NORD-MOD-END \*\/\n?/g, "");
fs.writeFileSync(cssPath, css);
' "$CSS"

node "$SCRIPT_DIR/gen-nord.js" "$CSS" "$WORK/nord.css"
cat "$WORK/nord.css" >> "$CSS"

# splash screen: black gradient -> Nord
HTML="$WORK/extract/out/renderer/index.html"
if [ -f "$HTML" ]; then
  sed -i '' 's/linear-gradient(180deg, #000000 0%, #151718 100%)/linear-gradient(180deg, #2E3440 0%, #3B4252 100%)/' "$HTML"
fi

echo "repacking..."
npx --yes @electron/asar@3 pack "$WORK/extract" "$WORK/app.asar" --unpack "{**/*.node,**/spawn-helper}"

# verify native modules match what the app has installed; abort without swapping otherwise
if ! diff -r "$WORK/app.asar.unpacked" "$RES/app.asar.unpacked" > /dev/null; then
  echo "ERROR: unpacked native set differs — aborting, original untouched. Please open an issue."
  exit 1
fi

mv "$WORK/app.asar" "$ASAR"
echo "done — restart ZCode to load the Nord theme (v$VERSION)."
