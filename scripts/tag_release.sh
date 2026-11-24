#!/usr/bin/env bash
# Tags a production release on the merge commit of its auto-production-release-X.Y.Z PR and
# opens a draft GitHub Release on that tag. Run by .github/workflows/tagRelease.yml on every
# push to main that changes NewRelicAgent.podspec or Package.swift; any other commit exits 0.
#
# Usage: scripts/tag_release.sh <commit-sha>
# Env:   GH_TOKEN          token with contents: write on this repo
#        GITHUB_REPOSITORY owner/repo (default newrelic/newrelic-ios-agent)
#        DRY_RUN=1         run the checks and print the tag and release commands
set -euo pipefail

SHA=$(git rev-parse --verify "${1:?usage: tag_release.sh <commit-sha>}^{commit}")
REPO="${GITHUB_REPOSITORY:-newrelic/newrelic-ios-agent}"

run() {
  if [[ -n "${DRY_RUN:-}" ]]; then
    printf 'DRY_RUN:'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

VERSION=$(git show "$SHA:NewRelicAgent.podspec" \
  | sed -nE 's/^[[:space:]]*s\.version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p')

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "NewRelicAgent.podspec at $SHA has version '$VERSION', not a production version. Nothing to tag."
  exit 0
fi

# merge_commit_sha matches only the PR this commit merged, not PRs that contain the commit.
PR=$(gh api "repos/$REPO/commits/$SHA/pulls" \
  --jq ".[] | select(.merge_commit_sha == \"$SHA\" and .base.ref == \"main\" and .head.ref == \"auto-production-release-$VERSION\") | .number")
if [[ -z "$PR" ]]; then
  echo "$SHA is not the merge of auto-production-release-$VERSION into main. Nothing to tag."
  exit 0
fi
echo "$SHA merged #$PR (auto-production-release-$VERSION)."

# Prints the commit an existing tag points at, peeling annotated tags.
TAGGED=$(git ls-remote origin "refs/tags/$VERSION" "refs/tags/$VERSION^{}" \
  | awk '{c=$1} /\^\{\}$/ {p=$1} END {print (p ? p : c)}')
if [[ "$TAGGED" == "$SHA" ]]; then
  echo "$VERSION is already tagged at $SHA."
  exit 0
elif [[ -n "$TAGGED" ]]; then
  echo "::error::Tag $VERSION already exists at $TAGGED, not at the release merge commit $SHA. Release tags are never moved; see .github/RELEASING.md."
  exit 1
fi

# The tag must describe the zip customers download, so check Package.swift against it.
PACKAGE=$(git show "$SHA:Package.swift")
URL=$(sed -nE 's/.*url:[[:space:]]*"([^"]+)".*/\1/p' <<<"$PACKAGE" | head -1)
CHECKSUM=$(sed -nE 's/.*checksum:[[:space:]]*"([0-9a-f]{64})".*/\1/p' <<<"$PACKAGE" | head -1)
EXPECTED_URL="https://download.newrelic.com/ios_agent/NewRelic_XCFramework_Agent_$VERSION.zip"
if [[ "$URL" != "$EXPECTED_URL" ]]; then
  echo "::error::Package.swift at $SHA points at '$URL', expected $EXPECTED_URL."
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
curl -fsSL --retry 3 -o "$WORK/agent.zip" "$URL"
ACTUAL=$(shasum -a 256 "$WORK/agent.zip" | awk '{print $1}')
if [[ "$ACTUAL" != "$CHECKSUM" ]]; then
  echo "::error::$URL has sha256 $ACTUAL; Package.swift at $SHA expects $CHECKSUM."
  exit 1
fi
echo "$URL matches the Package.swift checksum."

run git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  tag -a "$VERSION" "$SHA" -m "New Relic iOS agent $VERSION"
# A plain push of an existing tag name is rejected, so this never overwrites a tag.
run git push origin "refs/tags/$VERSION"
run gh release create "$VERSION" --repo "$REPO" --verify-tag --draft \
  --title "$VERSION" \
  --notes "Paste the $VERSION release notes here before publishing: https://docs.newrelic.com/docs/release-notes/mobile-release-notes/ios-release-notes/"

echo "Tagged $VERSION at $SHA and opened a draft release. Add the release notes and publish it."
