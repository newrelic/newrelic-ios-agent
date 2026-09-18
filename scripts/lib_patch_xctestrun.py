#!/usr/bin/env python3
"""Inject environment variables into every test target in an .xctestrun file.

Xcode's scheme "Diagnostics" checkboxes are not serialized in a form that
`xcodebuild build-for-testing` bakes into the .xctestrun, so setting zombies via a
scheme is unreliable. Patching the .xctestrun is explicit and verifiable: the file is
the complete launch spec that `test-without-building` consumes.

Handles both the legacy layout (test target names as top-level keys) and the newer
TestConfigurations layout.
"""
import plistlib
import sys


def targets(doc):
    """Yield every test-target dict in either xctestrun layout."""
    if "TestConfigurations" in doc:
        for config in doc.get("TestConfigurations") or []:
            for target in config.get("TestTargets") or []:
                yield target
        return
    for key, value in doc.items():
        if key.startswith("__"):
            continue
        if isinstance(value, dict):
            yield value


def main():
    if len(sys.argv) < 3:
        print("usage: lib_patch_xctestrun.py <file.xctestrun> KEY=VALUE [KEY=VALUE ...]",
              file=sys.stderr)
        return 2

    path = sys.argv[1]
    env = {}
    for pair in sys.argv[2:]:
        key, _, value = pair.partition("=")
        env[key] = value

    with open(path, "rb") as handle:
        doc = plistlib.load(handle)

    patched = 0
    for target in targets(doc):
        existing = target.get("EnvironmentVariables")
        if not isinstance(existing, dict):
            existing = {}
        existing.update(env)
        target["EnvironmentVariables"] = existing
        patched += 1

    if patched == 0:
        print("error: no test targets found in %s" % path, file=sys.stderr)
        return 1

    with open(path, "wb") as handle:
        plistlib.dump(doc, handle)

    print("patched %d test target(s) with: %s" % (patched, " ".join(sorted(env))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
