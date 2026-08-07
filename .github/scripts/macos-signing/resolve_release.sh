#!/usr/bin/env bash

# Resolve release version, tag, name, and desktop/CLI channels for the
# macos-arm64-signed workflow.
#
# Env inputs:
#   INPUT_RELEASE_VERSION  optional override
#   INPUT_CHANNEL          prod|beta|dev (default prod)
#   GITHUB_SHA             required
#   GITHUB_OUTPUT          required in Actions
#   WORKSPACE              optional repo root (default cwd)

set -euo pipefail

workspace="${WORKSPACE:-.}"
tag_prefix="macos-arm64-v"
short_sha_re='[0-9a-f]{7}'
version_re='[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?'

package_json="${workspace}/packages/opencode/package.json"
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
else
  release_version="${source_version}"
  version_source="packages/opencode/package.json"
fi

if [[ ! "${release_version}" =~ ^${version_re}$ ]]; then
  echo "Release version '${release_version}' is unsupported" >&2
  exit 1
fi

if [[ "${release_version}" == "0.0.0" || "${release_version}" == 0.0.0-* ]]; then
  echo "Refusing placeholder version '${release_version}'" >&2
  exit 1
fi

if [[ -z "${GITHUB_SHA:-}" || "${#GITHUB_SHA}" -lt 7 ]]; then
  echo "GITHUB_SHA is missing or too short" >&2
  exit 1
fi

short_sha="${GITHUB_SHA:0:7}"
if [[ ! "${short_sha}" =~ ^${short_sha_re}$ ]]; then
  echo "Could not derive a 7-character commit sha from GITHUB_SHA='${GITHUB_SHA}'" >&2
  exit 1
fi

# Always bind the tag to the built commit. No fixed-tag override.
release_tag="${tag_prefix}${release_version}-${short_sha}"
release_name="${release_version} (macos-arm64 ${short_sha})"

# Desktop channel vs Script channel: prod embeds "latest" in the CLI binary.
channel="${INPUT_CHANNEL:-prod}"
case "${channel}" in
  prod) cli_channel="latest" ;;
  beta|dev) cli_channel="${channel}" ;;
  *)
    echo "Unsupported channel '${channel}'" >&2
    exit 1
    ;;
esac

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "release_tag=${release_tag}"
    echo "release_version=${release_version}"
    echo "release_name=${release_name}"
    echo "channel=${channel}"
    echo "cli_channel=${cli_channel}"
  } >>"${GITHUB_OUTPUT}"
fi

echo "OpenCode ${release_version} from ${version_source}; tag ${release_tag}; channel ${channel}; cli_channel ${cli_channel}"
