#!/usr/bin/env bash

# Submit a signed DMG to Apple notarization, wait for acceptance, staple,
# and hard-validate the staple ticket on the DMG itself.
#
# electron-builder with notarize:true staples the .app, not always the outer
# .dmg. Call this after packaging so the distributed DMG carries a ticket.
#
# Required env: APPLE_ID, APPLE_TEAM_ID, APPLE_APP_SPECIFIC_PASSWORD
# Optional env: NOTARY_TIMEOUT (default 45m), REPORT_DIR

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: notarize_and_staple_dmg.sh DMG_PATH" >&2
  exit 2
fi

dmg="$1"
if [[ ! -f "$dmg" ]]; then
  echo "DMG not found: $dmg" >&2
  exit 1
fi

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required}"

notary_timeout="${NOTARY_TIMEOUT:-45m}"
report_dir="${REPORT_DIR:-${GITHUB_WORKSPACE:-.}/macos-notarization/desktop-mac-arm64}"
mkdir -p "$report_dir"
report_path="${report_dir}/dmg-notarytool-submit.json"

echo "Notarizing DMG: $dmg"
codesign --verify --strict --verbose=2 "$dmg"

xcrun notarytool submit "$dmg" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait \
  --timeout "$notary_timeout" \
  --output-format json \
  | tee "$report_path"

python3 - "$report_path" <<'PY'
import json
import sys

report_path = sys.argv[1]
with open(report_path, encoding="utf-8") as report_file:
    report = json.load(report_file)
if report.get("status") != "Accepted":
    raise SystemExit(f"Notarization was not accepted: {report}")
print("Notarization Accepted")
PY

echo "Stapling notarization ticket onto DMG..."
xcrun stapler staple -v "$dmg"
xcrun stapler validate -v "$dmg"
shasum -a 256 "$dmg" >"${report_dir}/dmg-sha256.txt"
echo "DMG notarized and stapled: $dmg"
