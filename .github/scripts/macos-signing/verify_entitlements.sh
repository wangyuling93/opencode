#!/usr/bin/env bash

# Ensure a signed binary has every entitlement key listed in a plist.
# Avoids brittle full-file equality against codesign dumps.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: verify_entitlements.sh BINARY ENTITLEMENTS_PLIST" >&2
  exit 2
fi

binary="$1"
entitlements="$2"

if [[ ! -f "$binary" ]]; then
  echo "Binary not found: $binary" >&2
  exit 1
fi

if [[ ! -f "$entitlements" ]]; then
  echo "Entitlements plist not found: $entitlements" >&2
  exit 1
fi

actual="$(mktemp)"
trap 'rm -f "$actual"' EXIT

codesign -d --entitlements :- "$binary" >"$actual" 2>/dev/null || {
  echo "Could not dump entitlements from $binary" >&2
  exit 1
}

# Required keys = every <key>…</key> in the expected plist.
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if ! grep -Fq "<key>${key}</key>" "$actual"; then
    echo "Missing entitlement on ${binary}: ${key}" >&2
    echo "Actual entitlements:" >&2
    cat "$actual" >&2
    exit 1
  fi
done < <(sed -n 's/.*<key>\([^<]*\)<\/key>.*/\1/p' "$entitlements")

echo "Required entitlements present on $binary"
