#!/bin/bash
# Restores the original, unmodded app.asar for the installed ZCode version.
set -euo pipefail

APP="${ZCODE_APP:-/Applications/ZCode.app}"
RES="$APP/Contents/Resources"
BACKUP_DIR="${ZCODE_BACKUP_DIR:-$HOME/.zcode/backup}"

VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
BAK="$BACKUP_DIR/app.asar.v$VERSION.bak"

if [ ! -f "$BAK" ]; then
  echo "no backup found for v$VERSION at $BAK"
  exit 1
fi

cp "$BAK" "$RES/app.asar"
echo "restored original app.asar (v$VERSION) — restart ZCode."
