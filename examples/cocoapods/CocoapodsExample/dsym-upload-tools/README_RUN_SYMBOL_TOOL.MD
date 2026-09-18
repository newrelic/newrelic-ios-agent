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


- Due to limitations with Swift scripting run-symbol-tool.swift is one file.
   Main script contents are in start() func. Helper functions are categorized at the end.
- Script will first attempt to convert each dSYM into NR map files, 
   then it will combine map files into zip file and upload to New Relic.
   If conversion isn't possible or zipped map files upload fails the dSYMs are uploaded to New Relic.