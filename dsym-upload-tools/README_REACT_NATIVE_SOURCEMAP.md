# React Native Source Map Upload Tool

This tool automatically uploads React Native JavaScript source maps to New Relic during iOS release builds. Source maps enable symbolication of JavaScript crashes in production, allowing you to see meaningful stack traces instead of minified code references.

## Prerequisites

- React Native iOS application
- New Relic iOS Agent integrated
- **New Relic Ingest API Key** ([Get one here](https://one.newrelic.com/api-keys))
- **New Relic Mobile App Token** (from your mobile app settings in New Relic)
- Xcode project with "Bundle React Native code and images" build phase configured

**Important:** Both the Ingest API Key and Mobile App Token must belong to the same New Relic account.

## Installation

### Step 1: Add Run Script Build Phase

1. In Xcode, select your project in the navigator
2. Click on your application target
3. Select the **Build Phases** tab
4. Click the **+** icon and choose **New Run Script Build Phase**
5. **Important:** Drag this new phase to run **AFTER** the "Bundle React Native code and images" phase
6. Name the phase "Upload React Native Source Maps" (optional but recommended)

### Step 2: Configure the Script

Add the following code to the Run Script phase, replacing the placeholder values:

```bash
SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
/bin/sh "${SCRIPT}" "YOUR_INGEST_API_KEY" "YOUR_APP_TOKEN"
```

Where:
- `YOUR_INGEST_API_KEY`: Your New Relic Ingest API Key ([Get it here](https://one.newrelic.com/api-keys))
- `YOUR_APP_TOKEN`: Your New Relic Mobile App Token (same token used by the iOS Agent)

### Step 3: Enable Source Map Generation (if not already enabled)

Ensure your React Native bundler is configured to generate source maps. This is typically configured in the "Bundle React Native code and images" build phase.

The default React Native Xcode script should include:
```bash
export SOURCEMAP_FILE="${DERIVED_FILE_DIR}/main.jsbundle.map"
```

If using a custom bundle command, ensure you include the `--sourcemap-output` parameter:
```bash
react-native bundle \
  --platform ios \
  --dev false \
  --entry-file index.js \
  --bundle-output "${BUILT_PRODUCTS_DIR}/main.jsbundle" \
  --sourcemap-output "${DERIVED_FILE_DIR}/main.jsbundle.map"
```

## Configuration Options

### Debug Mode

Add `--debug` as the third argument to enable verbose logging:

```bash
SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
/bin/sh "${SCRIPT}" "YOUR_INGEST_API_KEY" "YOUR_APP_TOKEN" --debug
```

Debug output is written to `upload_sourcemap_results.log` in your project root.

### Environment Variables

You can customize the upload behavior using these environment variables in your build phase:

#### NEWRELIC_SOURCEMAP_UPLOAD_DISABLED
Disable source map upload without removing the build phase.

```bash
export NEWRELIC_SOURCEMAP_UPLOAD_DISABLED="true"
```

#### SOURCEMAP_PATH
Override the default source map location.

```bash
export SOURCEMAP_PATH="${DERIVED_FILE_DIR}/custom-bundle.map"
```

#### SOURCEMAP_UPLOAD_URL
Override the New Relic Symbol Ingest API endpoint (for EU regions or testing).

```bash
export SOURCEMAP_UPLOAD_URL="https://symbol-ingest-api.eu01.nr-data.net"
```

#### NEWRELIC_JS_BUNDLE_ID
Override the automatically generated JS Bundle ID with a custom value.

```bash
export NEWRELIC_JS_BUNDLE_ID="my-custom-build-id"
```

By default, the script generates: `{appVersion}.{buildNumber}-{shortUUID}`

## How It Works

1. The script runs only during **Release** configuration builds
2. It skips simulator builds automatically
3. Reads metadata from your app's `Info.plist`:
   - **App Version** (`CFBundleShortVersionString`)
   - **Build Number** (`CFBundleVersion`)
4. Generates a **JS Bundle ID** (git commit SHA or build number)
5. Uploads the source map to New Relic via multipart form POST
6. Runs in the background to avoid delaying your build

## Uploaded Metadata

The following data is sent with each source map upload:

| Field | Description | Example |
|-------|-------------|---------|
| `sourcemap` | The source map file | `main.jsbundle.map` |
| `jsBundleId` | Unique identifier for this build | `1.2.3.42-a1b2c3d4` (appVersion.buildNumber-shortUUID) |
| `appVersionId` | App marketing version | `1.2.3` |
| `sourcemapName` | Name of the source map | `main.jsbundle.map` |

### JS Bundle ID Format

The script automatically generates a unique, human-readable identifier:
```
Format: {appVersion}.{buildNumber}-{shortUUID}
Example: 1.2.3.42-a1b2c3d4
```

This ensures each upload is unique while remaining easy to identify in listings.

## Troubleshooting

### Source map not found error

**Error:** `Source map not found at: /path/to/main.jsbundle.map`

**Solutions:**
1. Ensure the "Bundle React Native code and images" phase completed successfully
2. Check that `SOURCEMAP_FILE` environment variable is set in the bundle phase
3. Verify the upload script runs **AFTER** the bundle phase (check Build Phases order)
4. Confirm you're building for Release configuration

### Invalid API Key (HTTP 403)

**Error:** `Upload failed: Invalid API key (HTTP 403)`

**Solutions:**
1. Verify you're using an **Ingest API Key**, not a User API Key
2. Get your API key from [https://one.newrelic.com/api-keys](https://one.newrelic.com/api-keys)
3. Check for extra spaces or quotes around the API key in your script

### File size too large (HTTP 413)

**Error:** `Source map exceeds 200MB limit`

**Solutions:**
1. Enable JavaScript minification in your Release builds
2. Use code splitting or dynamic imports to reduce bundle size
3. Consider using [Hermes engine](https://reactnative.dev/docs/hermes) which produces smaller bundles

### Script doesn't run

**Check these items:**
1. Verify the build phase is enabled (checkbox is checked)
2. Ensure you're building with Release configuration
3. Check you're building for device, not simulator
4. Look for errors in the Xcode build log

### Viewing upload logs

Check `upload_sourcemap_results.log` in your project root directory for detailed output. Enable debug mode for more verbose logging:

```bash
SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
/bin/sh "${SCRIPT}" "YOUR_API_KEY" --debug
```

## Best Practices

### 1. Automatic Unique Identifiers

The script automatically generates unique, readable JS Bundle IDs in the format:
```
{appVersion}.{buildNumber}-{shortUUID}
Example: 1.2.3.42-a1b2c3d4
```

No additional configuration needed! Each build gets a guaranteed unique identifier.

### 2. Custom Build Identifiers (Optional)

If you use a CI/CD system with build IDs, you can override the automatic identifier:

```bash
export NEWRELIC_JS_BUNDLE_ID="${CI_BUILD_ID}"
SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
/bin/sh "${SCRIPT}" "YOUR_INGEST_API_KEY" "YOUR_APP_TOKEN"
```

### 3. Store Credentials Securely

Don't commit your API keys to version control. Instead:

**Option A:** Use Xcode build configuration files (`.xcconfig`)
```bash
// Config/Release.xcconfig
NEWRELIC_INGEST_KEY = your_ingest_key_here
NEWRELIC_APP_TOKEN = your_app_token_here
```

Then in your build phase:
```bash
SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
/bin/sh "${SCRIPT}" "${NEWRELIC_INGEST_KEY}" "${NEWRELIC_APP_TOKEN}"
```

**Option B:** Use environment variables from your CI/CD system
```bash
SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
/bin/sh "${SCRIPT}" "${NEWRELIC_INGEST_KEY}" "${NEWRELIC_APP_TOKEN}"
```

### 4. Test with Debug Mode First

Before deploying to production, test the upload with debug mode enabled to verify configuration:

```bash
SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
/bin/sh "${SCRIPT}" "YOUR_INGEST_API_KEY" "YOUR_APP_TOKEN" --debug
```

Check `upload_sourcemap_results.log` for any errors or warnings.

## Verifying Uploads

After a successful upload, you can verify in New Relic:

1. Go to [New Relic One](https://one.newrelic.com)
2. Navigate to your Mobile application
3. View a JavaScript crash/error
4. Verify the stack trace is symbolicated (shows actual function names and line numbers)

## Support

For issues or questions:
- [New Relic iOS Agent Documentation](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios)
- [GitHub Issues](https://github.com/newrelic/newrelic-ios-agent/issues)
- [New Relic Support](https://support.newrelic.com)

## Related Documentation

- [React Native Integration Guide](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-react-native)
- [Mobile Errors API](https://docs.newrelic.com/docs/mobile-monitoring/mobile-monitoring-ui/crashes/introduction-mobile-handled-exceptions)
- [Source Map Symbolication](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile/get-started/introduction-mobile-monitoring)
