## Swift script used to upload a builds symbols to New Relic.
### Intended to be run from a Xcode build phase.

 1. In Xcode, select your project in the navigator, then click on the application target.
 2. Select the Build Phases tab in the settings editor.
 3. Click the + icon above Target Dependencies and choose New Run Script Build Phase.
 4. Add the following lines of code to the new phase, pasting in the
     application token as "APP_TOKEN" from your New Relic dashboard for the app in question.
 
```
    SCRIPT=`/usr/bin/find "${SRCROOT}/../.." -name run-symbol-tool | head -n 1`
    /bin/sh "${SCRIPT}" "APP_TOKEN"
```

Optional:

Note: A few environment variables can be set to modify the behavior of the map or dSYM uploader.
- DSYM_UPLOAD_URL: Host URL to use when uploading to New Relic. default: "https://mobile-symbol-upload.newrelic.com"
- NEWRELIC_SYMBOL_ENDPOINT: Symbol endpoint. default: "map"
- NEWRELIC_DSYM_ENDPOINT: Dsym endpoint. default: "symbol"
- NEWRELIC_SYMBOL_POST_KEY: Symbol Post Key used in Curl. default: "upload"
- NEWRELIC_DSYM_POST_KEY: Dsym Post Key used in Curl. default: "dsym"
- NEWRELIC_APP_VERSION: App version reported in the `X-NewRelic-App-Version` header. Overrides `MARKETING_VERSION`. Equivalent to passing `-appVersion` on the command line.
- NEWRELIC_SYMBOL_UPLOAD_CONCURRENCY: How many dSYM binaries are converted and uploaded in parallel. default: 4. Set to 1 to process them one at a time.

Add "--debug" after last line of script to enable debug logs in the output `upload_dsym_results.log` file.

```
    SCRIPT=`/usr/bin/find "${SRCROOT}/../.." -name run-symbol-tool | head -n 1`
    /bin/sh "${SCRIPT}" "APP_TOKEN" --debug
```

## Setting the app version explicitly (`-appVersion`)

Uploaded symbols are associated with your app's version via the `X-NewRelic-App-Version` header. By default this value comes from the `MARKETING_VERSION` build setting. Some projects don't set `MARKETING_VERSION` — for example apps that manage versioning with `agvtool`, or multi-target apps built with `GENERATE_INFOPLIST_FILE = YES`. In those cases the reported version can be empty or a placeholder, and uploaded symbol maps will not match your builds.

To set the version explicitly, pass `-appVersion` after the app token. It can be combined with `--debug` in any order.

```
    SCRIPT=`/usr/bin/find "${SRCROOT}/../.." -name run-symbol-tool | head -n 1`
    /bin/sh "${SCRIPT}" "APP_TOKEN" -appVersion "7.8.2"
```

The app version is resolved with the following precedence:

1. `-appVersion <version>` command-line argument
2. `NEWRELIC_APP_VERSION` environment variable
3. `MARKETING_VERSION` environment variable
4. a built-in placeholder (a warning is logged in `upload_dsym_results.log` when this fallback is used)

DSYM_UPLOAD_URL - define this environment variable above run script to override the New Relic server hostname


```
export DSYM_UPLOAD_URL="https://staging-mobile-symbol-upload.newrelic.com"
```

Repeat this line for each Env Var you'd like to set.

```
export NEWRELIC_SYMBOL_ENDPOINT="map2"
```


## Seeing the output in Xcode (`--foreground`)

By default the upload runs in the background and writes to `upload_dsym_results.log`, so the build doesn't wait.
Add `--foreground` to run it inside the build phase instead: the output appears in the Xcode build log and the
build waits until the upload finishes. This is also useful on CI, where a background upload can be cut off when the job ends.

```
    SCRIPT=`/usr/bin/find "${SRCROOT}/../.." -name run-symbol-tool | head -n 1`
    /bin/sh "${SCRIPT}" "APP_TOKEN" --foreground
```

Build phases that run the Swift file directly (`/usr/bin/xcrun --sdk macosx swift run-symbol-tool.swift "APP_TOKEN"`)
keep working: `run-symbol-tool.swift` forwards to the wrapper in the foreground.

## How it works

- Script will first attempt to convert each dSYM into NR map files,
   then it will combine map files into zip file and upload to New Relic.
   If conversion isn't possible or the zipped map file upload fails, the dSYMs are uploaded to New Relic.
   There is no dSYM fallback when the app token is rejected (HTTP 401/403) or the server can't be reached
   (DNS, connection or TLS failure), since the dSYM upload would fail the same way; the remaining binaries are
   then skipped too.
- Zipped map files larger than 200MB are not uploaded; a telemetry request reporting the size is sent instead.
- Several dSYM binaries (app, extensions, frameworks) are processed in parallel. Binaries over 100MB are processed
   first, one at a time, to limit memory use. A `New Relic: Processing <path>` line is logged when each binary
   starts; the rest of its lines are written together when it finishes, and the log ends with a summary line.
- Copy the entire `dsym-upload-tools` folder, including `Sources/`, into your project (if `Sources/` is missing,
   the build phase shows a warning and nothing is uploaded). The `run-symbol-tool`
   wrapper compiles `Sources/SymbolTool/*.swift` with `swiftc` and caches the binary in the per-user cache
   directory (`getconf DARWIN_USER_CACHE_DIR`, under `com.newrelic.dsym-upload-tools`), keyed on a hash of the
   sources. The first build after the tool changes compiles it (a few seconds); later builds reuse the cached
   binary. Binaries unused for 30 days are removed.

## Source layout (`Sources/SymbolTool`)

| File | Responsibility |
|---|---|
| `main.swift` | Entry point. |
| `RunSymbolTool.swift` | Build-environment checks (Bitcode, simulator, `$DWARF_DSYM_FOLDER_PATH`), parallel processing of binaries, summary. |
| `CommandLineOptions.swift` | Parses `<APP_TOKEN> [--debug] [-appVersion <version>]`. |
| `Configuration.swift` | Environment variables, app-version precedence, region-aware upload URL. |
| `DSYMLocator.swift` | Finds the DWARF binaries inside each `.dSYM` bundle. |
| `MapFileConverter.swift` | Runs `symbols -uuid` / `symbols -arch` for each binary. |
| `SymbolsOutputParser.swift`, `SymbolMap.swift` | Parse `symbols` output (byte-level, for large apps) and render New Relic map files. |
| `Archiver.swift` | Per-run scratch directories and zipping. |
| `SymbolUploader.swift` | Map / dSYM / telemetry uploads via `curl`. |
| `SymbolUploadPipeline.swift` | Map upload with dSYM fallback for a single binary. |
| `CommandRunner.swift`, `Logger.swift` | Process execution (argument arrays, no shell) and logging; the app token is masked wherever it is logged. |

## Development

Unit tests live in `Tests/SymbolToolTests`. The map format is pinned to the original single-file tool in two ways:
the `.map` fixtures are golden files it produced, and `SymbolsParserDifferentialTests` compares the parser with
`LegacySymbolsParser` (the original parsing code) on generated output, including non-ASCII names and paths.
Run them from the repository root, keeping the build folder out of `dsym-upload-tools` (this folder is copied
into customer projects; the release copy steps exclude `Tests/`, `Package.swift` and build folders):

```
swift test --package-path dsym-upload-tools --scratch-path "${TMPDIR:-/tmp}/nr-dsym-upload-tools-build"
```

Or run the full lane, including a foreground run of the tool: `bundle exec fastlane ios runDsymUploadToolsTests`.
