#!/usr/bin/env bash

# Fails if any .swiftinterface in the given XCFramework uses module selectors
# (`NewRelic::Foo`). See interface_xcargs in fastlane/BuildFastfile.

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: $0 path/to/NewRelic.xcframework"
  exit 1
fi

XCFRAMEWORK="$1"
SELECTOR_PATTERN='[A-Za-z_][A-Za-z0-9_]*::[A-Za-z_]'

checked=0
failed=0

while IFS= read -r -d '' interface; do
  checked=$((checked + 1))

  count=$(grep -cE "${SELECTOR_PATTERN}" "${interface}")
  if [ "${count}" -ne 0 ]; then
    echo "error: ${interface} has ${count} line(s) with module selectors:"
    grep -nE -m 3 "${SELECTOR_PATTERN}" "${interface}" | sed 's/^/    /'
    failed=1
  fi
done < <(find "${XCFRAMEWORK}" -name "*.swiftinterface" -print0)

if [ "${checked}" -eq 0 ]; then
  echo "error: no .swiftinterface files found in ${XCFRAMEWORK}"
  exit 1
fi

if [ "${failed}" -ne 0 ]; then
  echo "Build with -Xfrontend -disable-module-selectors-in-module-interface (see fastlane/BuildFastfile)."
  exit 1
fi

echo "No module selectors found in ${checked} .swiftinterface files."
