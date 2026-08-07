#!/usr/bin/env bash

# Fail fast if the codesigning GitHub environment is incomplete.
# Expects secrets/vars already exported into the process environment.

set -euo pipefail

missing=0
for name in \
  APPLE_DEVELOPER_ID_P12 \
  APPLE_DEVELOPER_ID_P12_PASSWORD \
  APPLE_APP_SPECIFIC_PASSWORD \
  APPLE_ID \
  APPLE_TEAM_ID
do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing codesigning value: $name" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Configure the 'codesigning' environment with:" >&2
  echo "  ./.github/scripts/setup-macos-signing-secrets.sh --repo OWNER/REPO" >&2
  exit 1
fi

if [[ "$APPLE_ID" != *@* ]]; then
  echo "APPLE_ID must be an email address, got: $APPLE_ID" >&2
  exit 1
fi

if [[ ! "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "APPLE_TEAM_ID must be 10 uppercase letters or digits, got: $APPLE_TEAM_ID" >&2
  exit 1
fi

echo "Codesigning environment is present (APPLE_ID=$APPLE_ID, APPLE_TEAM_ID=$APPLE_TEAM_ID)."
