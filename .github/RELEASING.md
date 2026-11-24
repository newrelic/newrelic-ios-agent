# Release tags and GitHub Releases

## Who creates what

| Ref | Created by | Points at |
|---|---|---|
| `X.Y.Z-rc.N` tag, this repo | `main.yml` (`deployStagingSpecs`) | the staging release commit |
| `X.Y.Z` tag, `newrelic-ios-agent-spm` | `productionDeploy.yml` | the "Added build X.Y.Z" commit |
| `X.Y.Z` tag and draft GitHub Release, this repo | `tagRelease.yml` | the merge commit of the `auto-production-release-X.Y.Z` PR |

Release tags are created only by these workflows. After merging the `auto-production-release-X.Y.Z` PR, open the draft release that `tagRelease.yml` created, paste in the release notes, and publish it.

If `tagRelease.yml` fails, fix the cause and re-run it with `workflow_dispatch`, passing the merge commit as `sha`. It fails when:

- `X.Y.Z` is already tagged at another commit.
- The `Package.swift` URL isn't `ios_agent/NewRelic_XCFramework_Agent_X.Y.Z.zip`.
- The published zip doesn't match the `Package.swift` checksum.

## A published tag is permanent

Release tags in this repo and in `newrelic-ios-agent-spm` are never moved or deleted. Swift Package Manager resolves a version through its tag and records the tag's commit in each app's `Package.resolved`, so a moved tag breaks resolution for every app pinned to it.

When a release is bad:

1. Ship the fix as the next patch version.
2. Edit the bad version's GitHub Release in both repos so it starts with `Do not use X.Y.Z: <reason>. Use X.Y.Z+1.`

## Tags that differ from their release

| Tag | Points at | Effect |
|---|---|---|
| `7.7.4` | `00ce7744`, the #807 merge | `Package.swift` and `NewRelicAgent.podspec` there reference the staging zip `ios-v5/NewRelic_XCFramework_Agent_7.7.4-rc.2511.zip`. Resolve 7.7.4 from `newrelic-ios-agent-spm`. |
| `7.7.9` | `8dd35621`, the #945 merge | One commit after the released #943 merge. #945 changes the PLCrashReporter submodule URL and the `modular-crash-reporter-ios` submodule commit. |
