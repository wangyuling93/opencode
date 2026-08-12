#!/usr/bin/env bash

# Reclaim disk on GitHub-hosted macOS runners before heavy packaging steps
# (hdiutil, electron-builder). Safe to run after the release binary has been
# staged outside the monorepo tree (e.g. under $RUNNER_TEMP).
#
# Optional env:
#   FREE_PACKAGING_KEEP_NODE_MODULES=true  skip node_modules deletion
#   FREE_PACKAGING_KEEP_DIST=true          skip packages/*/dist deletion
#   GITHUB_WORKSPACE / RUNNER_TEMP         standard Actions paths

set -euo pipefail

workspace="${GITHUB_WORKSPACE:-}"
runner_temp="${RUNNER_TEMP:-/tmp}"

report_disk() {
  local label="$1"
  echo "=== disk ${label} ==="
  df -h / "$runner_temp" ${workspace:+"$workspace"} 2>/dev/null || df -h
  if [[ -n "$workspace" && -d "$workspace" ]]; then
    du -sh "$workspace" 2>/dev/null || true
  fi
}

if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
  echo "Not running on GitHub Actions; skipping packaging free-space cleanup."
  exit 0
fi

report_disk "before free"

# Caches (always safe).
rm -rf "${HOME}/.bun/install/cache" 2>/dev/null || true
rm -rf "${HOME}/.npm/_cacache" 2>/dev/null || true
rm -rf "${HOME}/Library/Caches/Homebrew" 2>/dev/null || true
rm -rf "${HOME}/Library/Caches/electron" 2>/dev/null || true
rm -rf "${HOME}/Library/Caches/electron-builder" 2>/dev/null || true
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData" 2>/dev/null || true

# Monorepo bulk: only after the signed artifact is staged outside the tree.
if [[ -n "$workspace" && -d "$workspace" ]]; then
  if [[ "${FREE_PACKAGING_KEEP_NODE_MODULES:-}" != "true" ]]; then
    # Prefer path globs over recursive find+rm (faster, less surprising).
    rm -rf "${workspace}/node_modules" 2>/dev/null || true
    rm -rf "${workspace}/packages/"*/node_modules 2>/dev/null || true
    rm -rf "${workspace}/packages/"*/*/node_modules 2>/dev/null || true
    rm -rf "${workspace}/packages/"*/*/*/node_modules 2>/dev/null || true
  fi

  if [[ "${FREE_PACKAGING_KEEP_DIST:-}" != "true" ]]; then
    # Drop intermediate package dist trees. CLI binary must already be copied out.
    rm -rf "${workspace}/packages/"*/dist 2>/dev/null || true
    rm -rf "${workspace}/packages/"*/*/dist 2>/dev/null || true
  fi
fi

# Clear leftover sparse images / temp DMGs from prior attempts on this runner.
rm -f "${runner_temp}/"*.dmg "${runner_temp}/"*.sparseimage 2>/dev/null || true

report_disk "after free"
