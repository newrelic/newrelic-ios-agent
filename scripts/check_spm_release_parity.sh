#!/usr/bin/env bash
# Checks that newrelic-ios-agent and newrelic-ios-agent-spm publish the same Swift package
# for each release, and mirrors this repo's GitHub Release to the SPM repo when it is missing.
#
# For each version it checks that:
#   - both repos have the tag, and Package.swift at the tag points at that version's XCFramework zip
#   - both checksums match the zip on download.newrelic.com
#   - both repos have a GitHub Release (the SPM one is created from this repo's if missing)
#
# Usage: scripts/check_spm_release_parity.sh [version ...]
#   With no versions, checks the RECENT_TAG_COUNT newest release tags on the SPM repo.
#
# Environment:
#   MAIN_REPO, SPM_REPO   owner/name of the two repos
#   MAIN_GH_TOKEN         token for reading MAIN_REPO (default: gh's own auth)
#   SPM_GH_TOKEN          token with contents:write on SPM_REPO, used to create Releases (default: gh's own auth)
#   KNOWN_BAD_MAIN_TAGS   space-separated tags whose Package.swift on MAIN_REPO has a wrong checksum.
#                         Released tags are not moved, so these are reported as warnings.
#   RECENT_TAG_COUNT      how many tags to check when no versions are given (default 5)
#   DRY_RUN=1             report missing Releases without creating them

set -euo pipefail

MAIN_REPO="${MAIN_REPO:-newrelic/newrelic-ios-agent}"
SPM_REPO="${SPM_REPO:-newrelic/newrelic-ios-agent-spm}"
KNOWN_BAD_MAIN_TAGS="${KNOWN_BAD_MAIN_TAGS:-}"
RECENT_TAG_COUNT="${RECENT_TAG_COUNT:-5}"
DRY_RUN="${DRY_RUN:-0}"

RELEASE_TAG_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

errors=0

gh_as() {
  local token=$1
  shift
  if [[ -n "$token" ]]; then
    GH_TOKEN="$token" gh "$@"
  else
    gh "$@"
  fi
}
gh_main() { gh_as "${MAIN_GH_TOKEN:-}" "$@"; }
gh_spm() { gh_as "${SPM_GH_TOKEN:-}" "$@"; }

report() {
  local level=$1 message=$2
  echo "::${level}::${message}"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    echo "- **${level}**: ${message}" >> "$GITHUB_STEP_SUMMARY"
  fi
  if [[ "$level" == "error" ]]; then
    errors=$((errors + 1))
  fi
}

spm_release_tags() {
  gh_spm api "repos/${SPM_REPO}/tags" --paginate --jq '.[].name' | grep -E "$RELEASE_TAG_PATTERN" | sort -V
}

# Prints Package.swift at a tag, or fails if the tag or file is missing.
package_swift() {
  local repo=$1 token=$2 tag=$3
  gh_as "$token" api "repos/${repo}/contents/Package.swift?ref=${tag}" -H "Accept: application/vnd.github.raw"
}

# Checks one repo's Package.swift at a tag against the expected zip URL and checksum.
check_package_swift() {
  local repo=$1 token=$2 version=$3 expected_checksum=$4 known_bad=$5
  local manifest url checksum level=error
  if [[ "$known_bad" == "1" ]]; then
    level=warning
  fi

  if ! manifest=$(package_swift "$repo" "$token" "$version" 2>/dev/null); then
    report error "${version}: ${repo} has no tag ${version} (or no Package.swift at it)"
    return
  fi

  url=$(grep -oE 'url: *"[^"]+"' <<< "$manifest" | sed -E 's/url: *"([^"]+)"/\1/')
  checksum=$(grep -oE 'checksum: *"[0-9a-f]+"' <<< "$manifest" | sed -E 's/checksum: *"([0-9a-f]+)"/\1/')

  if [[ "$url" != "$EXPECTED_URL" ]]; then
    report "$level" "${version}: ${repo} Package.swift points at '${url}', expected '${EXPECTED_URL}'"
  elif [[ "$checksum" != "$expected_checksum" ]]; then
    report "$level" "${version}: ${repo} Package.swift checksum is ${checksum}, the zip's is ${expected_checksum}"
  else
    echo "${version}: ${repo} Package.swift ok"
  fi
}

# Creates the SPM repo's Release from this repo's when it is missing.
mirror_release() {
  local version=$1 newest=$2
  local has_main_release=0 has_spm_release=0

  if gh_main release view "$version" --repo "$MAIN_REPO" --json name,body > "${WORK_DIR}/release.json" 2>/dev/null; then
    has_main_release=1
  else
    report error "${version}: ${MAIN_REPO} has no GitHub Release"
  fi
  if gh_spm release view "$version" --repo "$SPM_REPO" --json tagName > /dev/null 2>&1; then
    has_spm_release=1
    echo "${version}: ${SPM_REPO} Release ok"
  fi

  if [[ "$has_spm_release" == "1" || "$has_main_release" == "0" ]]; then
    if [[ "$has_spm_release" == "0" ]]; then
      report error "${version}: ${SPM_REPO} has no GitHub Release, and there is none on ${MAIN_REPO} to copy"
    fi
    return
  fi

  local title latest=false
  title=$(jq -r '.name // empty' "${WORK_DIR}/release.json")
  jq -r '.body // ""' "${WORK_DIR}/release.json" > "${WORK_DIR}/notes.md"
  # Backfilling an older version must not take the Latest badge from the newest one.
  if [[ "$version" == "$newest" ]]; then
    latest=true
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    report warning "${version}: ${SPM_REPO} has no GitHub Release (dry run, would create '${title:-$version}', latest=${latest})"
    return
  fi

  if gh_spm release create "$version" --repo "$SPM_REPO" --verify-tag \
      --title "${title:-$version}" --notes-file "${WORK_DIR}/notes.md" --latest="$latest"; then
    report notice "${version}: created the missing ${SPM_REPO} GitHub Release from ${MAIN_REPO}'s"
  else
    report error "${version}: failed to create the ${SPM_REPO} GitHub Release"
  fi
}

check_version() {
  local version=$1 newest=$2
  local zip="${WORK_DIR}/agent.zip" zip_checksum known_bad=0

  if [[ ! "$version" =~ $RELEASE_TAG_PATTERN ]]; then
    echo "${version}: not a release tag, skipping"
    return
  fi
  if [[ " ${KNOWN_BAD_MAIN_TAGS} " == *" ${version} "* ]]; then
    known_bad=1
  fi

  EXPECTED_URL="https://download.newrelic.com/ios_agent/NewRelic_XCFramework_Agent_${version}.zip"
  if ! curl -fsSL -o "$zip" "$EXPECTED_URL"; then
    report error "${version}: could not download ${EXPECTED_URL}"
    return
  fi
  # SPM's binary target checksum is the SHA-256 of the zip (same as `swift package compute-checksum`).
  zip_checksum=$(shasum -a 256 "$zip" | cut -d ' ' -f 1)

  check_package_swift "$SPM_REPO" "${SPM_GH_TOKEN:-}" "$version" "$zip_checksum" 0
  check_package_swift "$MAIN_REPO" "${MAIN_GH_TOKEN:-}" "$version" "$zip_checksum" "$known_bad"
  mirror_release "$version" "$newest"
}

all_tags=$(spm_release_tags)
newest=$(tail -n 1 <<< "$all_tags")

if [[ $# -gt 0 ]]; then
  versions=("$@")
else
  versions=()
  while IFS= read -r tag; do
    versions+=("$tag")
  done < <(tail -n "$RECENT_TAG_COUNT" <<< "$all_tags")
fi

for version in "${versions[@]}"; do
  check_version "$version" "$newest"
done

if [[ "$errors" -gt 0 ]]; then
  echo "${errors} problem(s) found"
  exit 1
fi
