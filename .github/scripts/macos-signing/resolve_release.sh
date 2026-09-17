#!/usr/bin/env bash

# Resolve release version, tag, name, and desktop/CLI channels for the
# macos-arm64 signed workflows.
#
# Env inputs:
#   INPUT_RELEASE_VERSION  optional override
#   INPUT_CHANNEL          opencode-2|classic-v1 (aliases: v2, prod, beta, dev, next)
#   GITHUB_SHA             required
#   GITHUB_OUTPUT          required in Actions
#   WORKSPACE              optional repo root (default cwd)
#   PACKAGE_JSON           optional path to package.json (default packages/opencode/package.json)
#   TAG_PREFIX             optional release tag prefix (default macos-arm64-v)
#   RELEASE_LABEL          optional label embedded in release name (default macos-arm64)
#   ALLOW_PREVIEW_VERSION  if true, allow 0.0.0-<channel>-* versions (default false)

set -euo pipefail

workspace="${WORKSPACE:-.}"
tag_prefix="${TAG_PREFIX:-macos-arm64-v}"
release_label="${RELEASE_LABEL:-macos-arm64}"
allow_preview_version="${ALLOW_PREVIEW_VERSION:-false}"
short_sha_re='[0-9a-f]{7}'
version_re='[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?'

if [[ -z "${GITHUB_SHA:-}" || "${#GITHUB_SHA}" -lt 7 ]]; then
  echo "GITHUB_SHA is missing or too short" >&2
  exit 1
fi

short_sha="${GITHUB_SHA:0:7}"
if [[ ! "${short_sha}" =~ ^${short_sha_re}$ ]]; then
  echo "Could not derive a 7-character commit sha from GITHUB_SHA='${GITHUB_SHA}'" >&2
  exit 1
fi

# User-facing product vs baked updater channels.
#   opencode-2  — OpenCode 2 from the v2 branch; CLI latest, desktop prod
#   classic-v1  — V1 from dev; CLI latest, desktop prod
channel="${INPUT_CHANNEL:-opencode-2}"
case "${channel}" in
  opencode-2 | v2)
    product="v2"
    cli_channel="latest"
    desktop_channel="prod"
    cli_dir="packages/cli/dist/cli-darwin-arm64"
    ;;
  classic-v1 | prod)
    product="v1"
    cli_channel="latest"
    desktop_channel="prod"
    cli_dir="packages/opencode/dist/opencode-darwin-arm64"
    ;;
  beta | dev | next)
    product="v2"
    cli_channel="${channel}"
    desktop_channel="${channel}"
    cli_dir="packages/cli/dist/cli-darwin-arm64"
    ;;
  *)
    echo "Unsupported product '${channel}'" >&2
    exit 1
    ;;
esac
cli_bin="${cli_dir}/bin/opencode"

if [[ -n "${PACKAGE_JSON:-}" ]]; then
  package_json="${PACKAGE_JSON}"
else
  package_json="${workspace}/packages/opencode/package.json"
fi
if [[ ! -f "$package_json" ]]; then
  echo "Missing $package_json" >&2
  exit 1
fi

source_version="$(
  python3 - "$package_json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
version = data.get("version")
if not isinstance(version, str) or not version:
    raise SystemExit(f"{path} has no version")
print(version)
PY
)"

if [[ -n "${INPUT_RELEASE_VERSION:-}" ]]; then
  release_version="${INPUT_RELEASE_VERSION}"
  version_source="workflow input"
elif [[ "$cli_channel" != "latest" && "$allow_preview_version" == "true" ]]; then
  # Match packages/script preview style: 0.0.0-<channel>-YYYYMMDDHHMM
  stamp="$(date -u +%Y%m%d%H%M)"
  release_version="0.0.0-${cli_channel}-${stamp}"
  version_source="preview auto (${cli_channel})"
else
  release_version="${source_version}"
  version_source="${package_json#"${workspace}/"}"
fi

if [[ ! "${release_version}" =~ ^${version_re}$ ]]; then
  echo "Release version '${release_version}' is unsupported" >&2
  exit 1
fi

if [[ "${release_version}" == "0.0.0" ]]; then
  echo "Refusing placeholder version '${release_version}'" >&2
  exit 1
fi

if [[ "${release_version}" == 0.0.0-* && "$allow_preview_version" != "true" ]]; then
  echo "Refusing preview version '${release_version}' (set ALLOW_PREVIEW_VERSION=true)" >&2
  exit 1
fi

# Always bind the tag to the built commit. No fixed-tag override.
release_tag="${tag_prefix}${release_version}-${short_sha}"
release_name="${release_version} (${release_label} ${short_sha})"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "release_tag=${release_tag}"
    echo "release_version=${release_version}"
    echo "release_name=${release_name}"
    echo "channel=${channel}"
    echo "product=${product}"
    echo "cli_channel=${cli_channel}"
    echo "desktop_channel=${desktop_channel}"
    echo "cli_dir=${cli_dir}"
    echo "cli_bin=${cli_bin}"
  } >>"${GITHUB_OUTPUT}"
fi

echo "OpenCode ${release_version} from ${version_source}; tag ${release_tag}; channel ${channel}; product ${product}; cli_channel ${cli_channel}; desktop_channel ${desktop_channel}"
