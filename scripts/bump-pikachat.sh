#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
VERSION_FILE="$ROOT/VERSION"

if [ $# -gt 1 ]; then
  echo "Usage: $0 [<version>]" >&2
  echo "Example: $0 1.1.0" >&2
  echo "When omitted, the repo-root VERSION value is used." >&2
  exit 1
fi

if [ $# -eq 1 ]; then
  VERSION="$1"
  "$ROOT/scripts/sync-pikachat-version" "$VERSION"
  INCLUDE_ROOT_VERSION=0
else
  VERSION="$("$ROOT/scripts/version-read" --name)"
  "$ROOT/scripts/sync-pikachat-version"
  INCLUDE_ROOT_VERSION=1
fi

TAG="pikachat-v${VERSION}"

# Stage and commit
git add "$ROOT/cli/Cargo.toml" \
  "$ROOT/pikachat-openclaw/openclaw/extensions/pikachat-openclaw/package.json" \
  "$ROOT/Cargo.lock"
if [ "$INCLUDE_ROOT_VERSION" -eq 1 ]; then
  git add "$VERSION_FILE"
fi
git commit -m "release: pikachat v${VERSION}"

# Tag
git tag "$TAG"

echo ""
echo "Done. To release:"
echo "  git push origin master $TAG"
