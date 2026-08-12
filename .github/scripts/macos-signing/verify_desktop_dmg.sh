#!/usr/bin/env bash

# Hard-verify a signed, notarized, stapled OpenCode desktop DMG.
# Mounts the image and checks the .app bundle signature and main binary arch.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: verify_desktop_dmg.sh DMG_PATH" >&2
  exit 2
fi

dmg="$1"
if [[ ! -f "$dmg" ]]; then
  echo "Desktop DMG not found: $dmg" >&2
  exit 1
fi

echo "Verifying desktop DMG: $dmg"
ls -lah "$dmg"

hdiutil verify "$dmg"
codesign --verify --strict --verbose=2 "$dmg"
xcrun stapler validate -v "$dmg"

mount_dir="${RUNNER_TEMP:-/tmp}/opencode-desktop-dmg-mount"
rm -rf "$mount_dir"
mkdir -p "$mount_dir"
hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount_dir"
cleanup_mount() {
  diskutil eject "$mount_dir" >/dev/null 2>&1 || true
}
trap cleanup_mount EXIT

app_path="$(find "$mount_dir" -maxdepth 1 -name "*.app" -type d | head -1)"
if [[ -z "$app_path" ]]; then
  echo "No .app bundle found in DMG" >&2
  ls -lah "$mount_dir" >&2 || true
  exit 1
fi

echo "Found app: $app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

plist="${app_path}/Contents/Info.plist"
macos_dir="${app_path}/Contents/MacOS"
if [[ ! -f "$plist" ]]; then
  echo "Missing Info.plist in app bundle" >&2
  exit 1
fi
if [[ ! -d "$macos_dir" ]]; then
  echo "Missing Contents/MacOS in app bundle" >&2
  exit 1
fi

exec_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
if [[ -z "$exec_name" ]]; then
  echo "CFBundleExecutable missing from Info.plist" >&2
  exit 1
fi

main_bin="${macos_dir}/${exec_name}"
if [[ ! -f "$main_bin" ]]; then
  echo "Main executable not found: $main_bin" >&2
  exit 1
fi

echo "Main executable: $main_bin"
if lipo "$main_bin" -info >/dev/null 2>&1; then
  lipo "$main_bin" -verify_arch arm64
fi
codesign --verify --strict --verbose=2 "$main_bin"

cleanup_mount
trap - EXIT

echo "Desktop DMG signature, staple, and arm64 checks passed."
