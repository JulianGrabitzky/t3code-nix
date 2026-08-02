#!/usr/bin/env bash
set -euo pipefail

repo="pingdotgg/t3code"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

api() {
  curl -sSfL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    ${GH_UPDATE_TOKEN:+-H "Authorization: Bearer ${GH_UPDATE_TOKEN}"} \
    "$1"
}

sri() {
  local digest="$1"
  nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}"
}

release_json() {
  local channel="$1"
  if [ "$channel" = stable ]; then
    api "https://api.github.com/repos/${repo}/releases/latest"
  else
    api "https://api.github.com/repos/${repo}/releases?per_page=100" \
      | jq -c '[.[] | select(.prerelease == true and (.tag_name | contains("nightly")))] | sort_by(.published_at) | last'
  fi
}

update_channel() {
  local channel="$1" json version linux x64 arm64
  json="$(release_json "$channel")"
  version="$(jq -r '.tag_name | sub("^v"; "")' <<<"$json")"

  asset_digest() {
    local suffix="$1"
    jq -r --arg suffix "$suffix" '.assets[] | select(.name | endswith($suffix)) | .digest' <<<"$json" | head -1
  }

  linux="$(asset_digest '-x86_64.AppImage')"
  x64="$(asset_digest '-x64.zip')"
  arm64="$(asset_digest '-arm64.zip')"

  for value in "$version" "$linux" "$x64" "$arm64"; do
    [ -n "$value" ] && [ "$value" != null ] || {
      echo "missing upstream metadata for $channel" >&2
      exit 1
    }
  done

  tmp="$(mktemp)"
  jq \
    --arg channel "$channel" \
    --arg version "$version" \
    --arg linux "$(sri "$linux")" \
    --arg x64 "$(sri "$x64")" \
    --arg arm64 "$(sri "$arm64")" \
    '.[$channel] = {
      version: $version,
      linuxHash: $linux,
      darwinX64Hash: $x64,
      darwinArm64Hash: $arm64
    }' versions.json > "$tmp"
  mv "$tmp" versions.json

  echo "$channel -> $version"
}

case "${1:-all}" in
  stable) update_channel stable ;;
  nightly) update_channel nightly ;;
  all)
    update_channel stable
    update_channel nightly
    ;;
  *) echo "usage: $0 [stable|nightly|all]" >&2; exit 2 ;;
esac

nix flake check --no-build
nix build .#t3code-stable .#t3code-nightly --no-link
