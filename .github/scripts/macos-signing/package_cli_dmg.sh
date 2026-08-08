#!/usr/bin/env bash

# Sign the OpenCode CLI binary, package a DMG, notarize, staple, and verify.
#
# Required env:
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_SPECIFIC_PASSWORD
#   SIGNING_IDENTITY
# Optional env:
#   SIGNING_KEYCHAIN   keychain name (e.g. build.keychain)
#   BINARY_PATH        default: packages/opencode/dist/opencode-darwin-arm64/bin/opencode
#   OUTPUT_DMG         default: dist/release-assets/opencode-cli-mac-arm64.dmg
#   ENTITLEMENTS       default: .github/scripts/macos-signing/opencode.entitlements.plist
#   BINARY_NAME        default: opencode
#   DMG_VOLNAME        default: OpenCode CLI (mac-arm64)
#   NOTARY_TIMEOUT     default: 45m
#   REPORT_DIR         default: macos-notarization/cli-mac-arm64

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="${GITHUB_WORKSPACE:-$(cd "${script_dir}/../../.." && pwd)}"

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required}"
: "${SIGNING_IDENTITY:?SIGNING_IDENTITY is required}"

binary_path="${BINARY_PATH:-${workspace}/packages/opencode/dist/opencode-darwin-arm64/bin/opencode}"
binary_name="${BINARY_NAME:-opencode}"
output_dmg="${OUTPUT_DMG:-${workspace}/dist/release-assets/opencode-cli-mac-arm64.dmg}"
entitlements="${ENTITLEMENTS:-${script_dir}/opencode.entitlements.plist}"
report_dir="${REPORT_DIR:-${workspace}/macos-notarization/cli-mac-arm64}"
notary_timeout="${NOTARY_TIMEOUT:-45m}"
dmg_volname="${DMG_VOLNAME:-OpenCode CLI (mac-arm64)}"
verify_entitlements="${script_dir}/verify_entitlements.sh"

if [[ ! -f "$binary_path" ]]; then
  echo "CLI binary not found: $binary_path" >&2
  exit 1
fi

if [[ ! -f "$entitlements" ]]; then
  echo "Entitlements not found: $entitlements" >&2
  exit 1
fi

sign() {
  local target="$1"
  shift
  local -a args=(--force)
  if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then
    args+=(--keychain "$SIGNING_KEYCHAIN")
  fi
  # codesign wants options, then -s identity, then the path.
  args+=("$@" --sign "$SIGNING_IDENTITY" "$target")
  codesign "${args[@]}"
}

chmod 0755 "$binary_path"

sign "$binary_path" \
  --options runtime \
  --timestamp \
  --identifier "$binary_name" \
  --entitlements "$entitlements"

lipo "$binary_path" -verify_arch arm64
codesign --verify --strict --verbose=2 "$binary_path"
"$verify_entitlements" "$binary_path" "$entitlements"

dmg_root="${RUNNER_TEMP:-/tmp}/opencode-cli-dmg-root"
rm -rf "$dmg_root"
mkdir -p "$dmg_root"
ditto "$binary_path" "${dmg_root}/${binary_name}"

stage_dir="$(dirname "$output_dmg")"
mkdir -p "$stage_dir" "$report_dir"
tmp_dmg="${RUNNER_TEMP:-/tmp}/opencode-cli-mac-arm64.dmg"
rm -f "$tmp_dmg"

hdiutil create \
  -volname "$dmg_volname" \
  -srcfolder "$dmg_root" \
  -format UDZO \
  -ov \
  "$tmp_dmg"

sign "$tmp_dmg" --timestamp
codesign --verify --strict --verbose=2 "$tmp_dmg"

report_path="${report_dir}/dmg-notarytool-submit.json"
xcrun notarytool submit "$tmp_dmg" \
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
PY

xcrun stapler staple -v "$tmp_dmg"
shasum -a 256 "$tmp_dmg" >"${report_dir}/dmg-sha256.txt"

# Single post-staple gate: container integrity + signature + staple + payload.
hdiutil verify "$tmp_dmg"
codesign --verify --strict --verbose=2 "$tmp_dmg"
xcrun stapler validate -v "$tmp_dmg"

mount_dir="${RUNNER_TEMP:-/tmp}/opencode-cli-dmg-mount"
rm -rf "$mount_dir"
mkdir -p "$mount_dir"
hdiutil attach "$tmp_dmg" -nobrowse -readonly -mountpoint "$mount_dir"
cleanup_mount() {
  diskutil eject "$mount_dir" >/dev/null 2>&1 || true
}
trap cleanup_mount EXIT
lipo "${mount_dir}/${binary_name}" -verify_arch arm64
codesign --verify --strict --verbose=2 "${mount_dir}/${binary_name}"
cleanup_mount
trap - EXIT

cp "$tmp_dmg" "$output_dmg"
ls -lah "$output_dmg"
echo "CLI DMG ready: $output_dmg"
