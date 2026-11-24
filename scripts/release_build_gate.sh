#!/usr/bin/env bash
# Decides whether a CI run builds, signs and uploads the agent to ios-v5/. Run by main.yml's releaseGate job.
#
#   staging    every push and workflow_dispatch run (the zip name carries -rc.<run number>)
#   main       workflow_dispatch runs, and pushes that change MARKETING_VERSION in Agent.xcodeproj.
#              The version reaches main only through the prod PR, so other merges (Dependabot, the
#              auto-production-release PR) are not built. The zip name is the bare X.Y.Z, so the gate
#              fails if ios-v5/ already has that version.
#   other refs never
#
# Usage: scripts/release_build_gate.sh <ref> <event-name> <before-sha> <sha>
# Writes deploy=true|false and version=X.Y.Z (main only) to $GITHUB_OUTPUT when it is set.
set -euo pipefail

REF="${1:?usage: release_build_gate.sh <ref> <event-name> <before-sha> <sha>}"
EVENT="${2:?}"
BEFORE="${3:-}"
SHA="${4:?}"
OUT="${GITHUB_OUTPUT:-/dev/null}"
ZERO_SHA="0000000000000000000000000000000000000000"

# Distinct numeric MARKETING_VERSION values in the project, one per line.
marketing_versions() {
  git show "${1}:Agent.xcodeproj/project.pbxproj" \
    | sed -nE 's/.*MARKETING_VERSION = ([0-9][0-9.]*);.*/\1/p' | sort -u
}

decide() {
  echo "deploy=$1" | tee -a "$OUT"
  [[ -n "${2:-}" ]] && echo "version=$2" | tee -a "$OUT"
  exit 0
}

case "$REF" in
  refs/heads/staging) decide true ;;
  refs/heads/main) ;;
  *) decide false ;;
esac

if [[ "$EVENT" == "push" ]]; then
  if [[ -z "$BEFORE" || "$BEFORE" == "$ZERO_SHA" ]]; then
    echo "No previous commit for this push; not building."
    decide false
  fi
  git cat-file -e "${BEFORE}^{commit}" 2>/dev/null || git fetch --quiet --depth=1 origin "$BEFORE"
  if [[ "$(marketing_versions "$BEFORE")" == "$(marketing_versions "$SHA")" ]]; then
    echo "MARKETING_VERSION is unchanged since ${BEFORE:0:8}; not building."
    decide false
  fi
elif [[ "$EVENT" != "workflow_dispatch" ]]; then
  decide false
fi

VERSION=$(marketing_versions "$SHA")
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Agent.xcodeproj at ${SHA:0:8} needs exactly one X.Y.Z MARKETING_VERSION, found: $(echo $VERSION)"
  exit 1
fi

URL="https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_${VERSION}.zip"
if curl -fsIL --retry 2 -o /dev/null "$URL"; then
  echo "::error::$URL already exists. A published build is never replaced; bump the version to ship a new build."
  exit 1
fi

echo "Building $VERSION from ${SHA:0:8}."
decide true "$VERSION"
