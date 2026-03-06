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
Override the automatically detected JS Bundle ID with a custom value.

```bash
export NEWRELIC_JS_BUNDLE_ID="my-custom-build-id"
```

By default, the script reads the `version` field from `package.json` (e.g., `"1.0.0"`).
If `package.json` is not found, it falls back to the native app version.

**Important:** This value must match the `jsAppVersion` parameter you pass when calling `NewRelic.recordJavascriptError()` in your React Native app. This is used to match errors with the correct source map for symbolication.

## How It Works

1. The script runs only during **Release** configuration builds
2. It skips simulator builds automatically
3. Reads metadata from your app's `Info.plist`:
   - **App Version** (`CFBundleShortVersionString`)
   - **Build Number** (`CFBundleVersion`)
4. Auto-detects **JS Bundle ID** from `package.json` version field
5. **Automatic compression** for large files:
   - Files over 50MB are automatically compressed to `.zip` format
   - Typical compression: 80-90% size reduction for source maps
   - Prevents upload failures due to 200MB API limit
6. Uploads the source map to New Relic via multipart form POST
7. Runs in the background to avoid delaying your build

### Automatic Compression

Source maps are JSON files that compress very well. The script automatically:
- Detects if the source map is larger than 50MB
- Compresses it to `.zip` format using the system `ditto` command
- Uploads the compressed version if it's smaller than 200MB
- Falls back to uncompressed if compression fails

**Example output:**
```
Source map size: 85.43MB
Compressing source map for upload...
Compressed size: 12.67MB (85.2% reduction)
✅ Source map uploaded successfully!
```

## Uploaded Metadata

The following data is sent with each source map upload:

| Field | Description | Example |
|-------|-------------|---------|
| `sourcemap` | The source map file | `main.jsbundle.map` |
| `jsBundleId` | Unique identifier for this build | `1.0.0` (from package.json) |
| `appVersionId` | App marketing version | `1.2.3` |
| `sourcemapName` | Name of the source map | `main.jsbundle.map` |

### JS Bundle ID

The script automatically detects the JS Bundle ID from your `package.json`:
```json
// package.json
{
  "version": "1.0.0"  // ← Used as jsBundleId
}
```

**Important for CodePush/OTA Updates:**
If you use CodePush or other OTA update mechanisms, you must manually set the `jsBundleId` to match your deployment:
```bash
export NEWRELIC_JS_BUNDLE_ID="1.0.0-v5"  # version + CodePush label
```

This same value must be passed when recording JavaScript errors in your React Native app.

## Troubleshooting

### Upload Error Codes

The upload script provides detailed error messages for all API responses:

#### HTTP 400 - Bad Request
**Meaning:** Validation failed on the source map file or request

**Common causes:**
- Source map version must be 3 (not version 1 or 2)
- Missing required fields (`jsBundleId`, `appVersionId`, `sourcemapName`)
- Invalid JSON format in the source map file
- ZIP file contains no valid files or multiple files
- Invalid file extension (must be `.map`, `.js.map`, `.json`, or `.zip`)

**Solutions:**
1. Verify your source map is generated correctly
2. Check that `SOURCEMAP_FILE` points to a valid `.map` file
3. Ensure React Native bundler is configured properly
4. Review `upload_sourcemap_results.log` for detailed error

#### HTTP 401 - Unauthorized
**Meaning:** API key and app token belong to different accounts

**Error message:** `"User not authorized"` (cross-account protection)

**Solutions:**
1. Verify both API key and app token are from the **same New Relic account**
2. Get Ingest API Key from: [https://one.newrelic.com/api-keys](https://one.newrelic.com/api-keys)
3. Get App Token from: New Relic mobile app settings

#### HTTP 403 - Forbidden
**Meaning:** API key doesn't have required capabilities

**Error message:** `"User not authorized"`

**Solutions:**
1. Use an **Ingest API Key**, not a User API Key
2. Verify the API key has "Insert" permission
3. Check for extra spaces or quotes in the API key

#### HTTP 404 - Not Found
**Meaning:** App token (X-APP-LICENSE-KEY) is invalid

**Error message:** `"applicationToken is invalid"`

**Solutions:**
1. Verify the app token in your `Info.plist` matches New Relic settings
2. Ensure the app token exists and hasn't been deleted
3. Check the app token is for the correct account

#### HTTP 413 - Payload Too Large
**Meaning:** Source map file exceeds 200MB limit (even after compression)

**Error message:** `"Sourcemap file is too large"`

**The script automatically:**
- Compresses files over 50MB to `.zip` format
- Typically achieves 80-90% size reduction
- Only uploads if compressed size is under 200MB

**If you still get this error:**
1. Enable JavaScript minification in Release builds
2. Use code splitting or dynamic imports to reduce bundle size
3. Switch to [Hermes engine](https://reactnative.dev/docs/hermes) (produces smaller bundles)
4. Check `upload_sourcemap_results.log` for compression details

#### HTTP 500 - Internal Server Error
**Meaning:** Unexpected server-side error

**Error message:** `"Unexpected error occurred during upload process because of {error}"`

**Solutions:**
1. Check `upload_sourcemap_results.log` for details
2. Retry the upload (transient server issue)
3. Contact New Relic support if issue persists

### Source map not found error

**Error:** `Source map not found at: /path/to/main.jsbundle.map`

**Solutions:**
1. Ensure the "Bundle React Native code and images" phase completed successfully
2. Check that `SOURCEMAP_FILE` environment variable is set in the bundle phase
3. Verify the upload script runs **AFTER** the bundle phase (check Build Phases order)
4. Confirm you're building for Release configuration

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

### 1. JS Bundle ID Must Match Between Upload and Errors

**Critical:** The `jsBundleId` used for sourcemap upload must match the `jsAppVersion` you pass when recording JavaScript errors.

```javascript
// In your React Native app
import { version } from './package.json';

NewRelic.recordJavascriptError(
  error.name,
  error.message,
  error.stack,
  false,
  version  // ← Must match the jsBundleId uploaded with sourcemap!
);
```

### 2. Automatic Detection from package.json

The script automatically reads from `package.json`:
```json
{
  "version": "1.0.0"  // ← Automatically used as jsBundleId
}
```

No additional configuration needed for standard builds!

### 3. CodePush / OTA Updates

If you use CodePush or other OTA update mechanisms:

```bash
# When releasing CodePush update
export NEWRELIC_JS_BUNDLE_ID="1.0.0-v5"  # version + CodePush label

# Upload sourcemap with matching ID
SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
/bin/sh "${SCRIPT}" "YOUR_INGEST_API_KEY" "YOUR_APP_TOKEN"
```

```javascript
// In your React Native app - detect CodePush label
import codePush from 'react-native-code-push';
import { version } from './package.json';

const update = await codePush.getUpdateMetadata();
const jsBundleId = update ? `${version}-${update.label}` : version;

NewRelic.recordJavascriptError(..., jsBundleId);
```

### 4. Store Credentials Securely

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

### 5. Test with Debug Mode First

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
