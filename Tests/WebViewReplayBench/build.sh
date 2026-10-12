#!/bin/zsh
# Builds one benchmark binary per branch, -O, against that branch's committed WebView replay sources
# (read with `git show`, so no worktree or checkout is needed and local edits never leak in).
# Sources are copied unmodified except the `#if os(iOS) || os(tvOS)` guard, so they compile on macOS.
#
#   build.sh                      both variants at their branch tips
#   POC_REF=abc123 build.sh       pin a variant to another commit (also TWO_REF)
set -euo pipefail
HERE=${0:A:h}
REPO=${REPO:-$(git -C $HERE rev-parse --show-toplevel)}
mkdir -p $HERE/build

build() {
  local name=$1 ref=$2 flags=$3; shift 3
  local rev=$(git -C $REPO rev-parse --short "${ref}^{commit}")
  local src=$HERE/build/$name-src
  rm -rf $src && mkdir -p $src
  for f in "$@"; do
    git -C $REPO show "${rev}:Agent/SessionReplay/WebView/${f}" | sed -e 's/^#if os(iOS) || os(tvOS)$/#if true/' > $src/$f
  done
  # The agent's own gzip, verbatim from SessionReplayReporter.swift.
  { echo 'import Foundation'; echo 'import zlib';
    git -C $REPO show "${rev}:Agent/SessionReplay/SessionReplayReporter.swift" | sed -n '/^extension Data {$/,/^  }$/p'; } > $src/Gzip.swift
  { echo "let benchVariant = \"$name\""; echo "let benchBranch = \"$ref\""; echo "let benchRev = \"$rev\""; } > $src/BuildInfo.swift
  xcrun swiftc -O -wmo $=flags -module-name Bench -o $HERE/build/bench-$name \
    $HERE/Stubs.swift $HERE/Fixtures.swift $HERE/main.swift $src/*.swift
  echo $rev > $HERE/build/$name.rev
  echo "built bench-$name  $ref @ $rev"
}

build poc        ${POC_REF:-webview-msr-poc}         ""          WebViewReplayRemapper.swift WebViewReplayChunkBuilder.swift
build twostreams ${TWO_REF:-two-streams-webview-msr} "-D PLUGIN" WebViewReplayEnvelope.swift WebViewReplayChunkBuilder.swift
