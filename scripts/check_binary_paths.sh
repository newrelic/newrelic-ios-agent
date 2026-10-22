#!/usr/bin/env bash

# Fails if any framework binary in the given XCFramework embeds an absolute
# build-machine path, typically from __FILE__ (C/ObjC) or #file (Swift 5 mode).
# App security scanners report these as "File Path Disclosure".
# Checks only the framework binaries; dSYMs contain source paths by design.

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: $0 path/to/NewRelic.xcframework"
  exit 1
fi

XCFRAMEWORK="$1"
PATH_PATTERN='/Users/|/Volumes/'

checked=0
failed=0

while IFS= read -r -d '' framework; do
  binary="${framework}/$(basename "${framework}" .framework)"

  if ! all_strings=$(strings -a -arch all "${binary}"); then
    echo "error: unable to read strings from ${binary}"
    failed=1
    continue
  fi
  checked=$((checked + 1))

  leaks=$(echo "${all_strings}" | grep -E "${PATH_PATTERN}" | sort -u)
  if [ -n "${leaks}" ]; then
    echo "error: ${binary} embeds $(echo "${leaks}" | wc -l | tr -d ' ') absolute build path(s):"
    echo "${leaks}" | sed 's/^/    /'
    failed=1
  fi
done < <(find "${XCFRAMEWORK}" -name "*.framework" -type d -print0)

if [ "${checked}" -eq 0 ]; then
  echo "error: no framework binaries found in ${XCFRAMEWORK}"
  exit 1
fi

if [ "${failed}" -ne 0 ]; then
  echo "Use __FILE_NAME__ instead of __FILE__ (C/ObjC) and #fileID instead of #file (Swift)."
  exit 1
fi

echo "No absolute build paths found in ${checked} framework binaries."
