#!/usr/bin/env bash
set -euo pipefail

repo="pingdotgg/t3code"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

api() {
  local url="$1"
  local args=(
    -sSfL
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28"
    -H "User-Agent: t3code-nix"
  )
  if [ -n "${GH_UPDATE_TOKEN:-}" ]; then
    args+=( -H "Authorization: Bearer ${GH_UPDATE_TOKEN}" )
  fi
  curl "${args[@]}" "$url"
}

sri() {
  nix hash convert --hash-algo sha256 --to sri "${1#sha256:}"
}

release_json() {
  if [ "$1" = stable ]; then
    api "https://api.github.com/repos/${repo}/releases/latest"
  else
    api "https://api.github.com/repos/${repo}/releases?per_page=100" \
      | jq -c '[.[] | select(.prerelease == true and (.tag_name | contains("nightly")))] | sort_by(.published_at) | last'
  fi
}

update_channel() {
  local channel="$1" json version digest hash tmp
  json="$(release_json "$channel")"
  version="$(jq -r '.tag_name | sub("^v"; "")' <<<"$json")"
  digest="$(jq -r '.assets[] | select(.name | endswith("-x86_64.AppImage")) | .digest' <<<"$json" | head -1)"

  [ -n "$version" ] && [ "$version" != null ] || { echo "missing $channel version" >&2; exit 1; }
  [ -n "$digest" ] && [ "$digest" != null ] || { echo "missing $channel AppImage digest" >&2; exit 1; }
  hash="$(sri "$digest")"

  tmp="$(mktemp)"
  jq \
    --arg channel "$channel" \
    --arg version "$version" \
    --arg hash "$hash" \
    '.[$channel] = { version: $version, linuxHash: $hash }' \
    versions.json > "$tmp"
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
nix build .#t3code-stable .#t3code-nightly --no-link --print-build-logs
