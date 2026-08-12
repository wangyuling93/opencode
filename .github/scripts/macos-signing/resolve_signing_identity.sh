#!/usr/bin/env bash

# Resolve the Developer ID Application identity from a named keychain only.
# Writes SIGNING_IDENTITY to GITHUB_ENV when available.

set -euo pipefail

keychain="${1:-}"
if [[ -z "$keychain" ]]; then
  echo "Usage: resolve_signing_identity.sh KEYCHAIN_NAME" >&2
  exit 2
fi

identities="$(security find-identity -v -p codesigning "$keychain")"
signing_identity="$(
  printf '%s\n' "$identities" | awk '/Developer ID Application:/ { print $2; exit }'
)"

if [[ -z "$signing_identity" ]]; then
  echo "No Developer ID Application identity found in keychain: $keychain" >&2
  printf '%s\n' "$identities" >&2
  exit 1
fi

echo "SIGNING_IDENTITY=${signing_identity}"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "SIGNING_IDENTITY=${signing_identity}" >>"$GITHUB_ENV"
fi
