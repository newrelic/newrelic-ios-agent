# NewRelic-SwiftPackage

`Package.swift.template` is the source for the release `Package.swift` in this repo and in [newrelic-ios-agent-spm](https://github.com/newrelic/newrelic-ios-agent-spm). Both URLs are SPM sources and must publish the same releases.

## Releasing the Swift package

1. Run the `productionDeploy` workflow on `main` with the version. It fills in the template, then pushes `Package.swift` and `dsym-upload-tools` to the SPM repo and tags it. It also opens the `[<version>] Production Release` PR here.
2. Merge that PR, then create the GitHub Release on this repo, tagged `<version>` at the merge commit. The tag must be on a commit whose root `Package.swift` has the production URL and checksum, because SPM resolves this repo's tags too.
3. Publishing the Release runs `spmReleaseParity`. It copies the Release to the SPM repo and checks that `Package.swift` at the tag matches the zip in both repos. If it fails, fix the cause and re-run it from the Actions tab with the version. It also runs weekly over the newest tags.

Generating a new checksum : 
When a new version of the xcframework is released use `swift package compute-checksum path/to/MyFramework.zip`  to generate a new checksum. This command must be run in the same folder as the package.swift.
