//
//  upload-react-native-sourcemap.swift
//  2025 New Relic
//
// Swift script used to upload React Native source maps to New Relic.
// Intended to be run from a Xcode build phase.
//
// 1. In Xcode, select your project in the navigator, then click on the application target.
// 2. Select the Build Phases tab in the settings editor.
// 3. Click the + icon above Target Dependencies and choose New Run Script Build Phase.
// 4. Add the following lines of code to the new phase AFTER "Bundle React Native code and images",
//    replacing YOUR_INGEST_API_KEY and YOUR_APP_TOKEN with your actual keys:
//
// ```
//  SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
//  /bin/sh "${SCRIPT}" "YOUR_INGEST_API_KEY" "YOUR_APP_TOKEN"
// ```
//
// Where:
//  - YOUR_INGEST_API_KEY: Get from https://one.newrelic.com/api-keys
//  - YOUR_APP_TOKEN: Your New Relic Mobile App Token (same one used by the agent)
//
// Optional:
//
// Add "--debug" as third argument to enable debug logs in the output upload_sourcemap_results.log file.
//
// ```
//  SCRIPT=`/usr/bin/find "${SRCROOT}" -name upload-react-native-sourcemap | head -n 1`
//  /bin/sh "${SCRIPT}" "YOUR_INGEST_API_KEY" "YOUR_APP_TOKEN" --debug
// ```
//
// Environment Variables (optional):
// SOURCEMAP_UPLOAD_URL - Override the New Relic server hostname
// SOURCEMAP_PATH - Override the default source map location (${DERIVED_FILE_DIR}/main.jsbundle.map)
// NEWRELIC_JS_BUNDLE_ID - Override the automatically generated JS Bundle ID
//
// ============================================================================
// START of Script upload-react-native-sourcemap.swift
import Foundation

let defaultURL = "https://symbol-ingest-api.newrelic.com"
let fileManager = FileManager.default
let environment = ProcessInfo.processInfo.environment
// Set to true for additional debug info in the upload_sourcemap_results.log file.
var debug = false

var sourcemapEndpointPath = "v1/react-native/sourcemaps"
var sourcemapUploadDataPostKey = "sourcemap"

// Maximum file size: 200MB
let maxFileSizeBytes: UInt64 = 209715200

enum SourceMapToolError: Error {
    case sourceMapNotFound
    case failedToUpload
    case fileTooLarge
    case invalidConfiguration
}

start()

func start() {
    print("New Relic: Starting React Native source map upload script...")

    // Only run for Release builds
    guard let configuration = environment["CONFIGURATION"], configuration == "Release" else {
        print("New Relic: Skipping source map upload (not a Release build)")
        exit(0)
    }

    // Skip simulator builds
    let platformName = environment["EFFECTIVE_PLATFORM_NAME"]
    if platformName == "-iphonesimulator" {
        print("New Relic: Skipping source map upload for simulator build")
        exit(0)
    }

    // Check for disabled flag
    if environment["NEWRELIC_SOURCEMAP_UPLOAD_DISABLED"] == "true" {
        print("New Relic: Source map upload is disabled via NEWRELIC_SOURCEMAP_UPLOAD_DISABLED")
        exit(0)
    }

    // Parse command line arguments
    guard CommandLine.arguments.count > 2 else {
        print("Invalid Usage: Ex: Swift: upload-react-native-sourcemap.swift $INGEST_API_KEY $APP_TOKEN [--debug]")
        print("New Relic: Please provide both:")
        print("  1. Ingest API Key (from https://one.newrelic.com/api-keys)")
        print("  2. Mobile App Token (from your New Relic mobile app settings)")
        exit(1)
    }
    let apiKey = CommandLine.arguments[1]
    let appToken = CommandLine.arguments[2]

    if CommandLine.arguments.count == 4 {
        let debugFlag = CommandLine.arguments[3]
        if debugFlag == "--debug" {
            debug = true
        }
    }

    // Configure Environment Variables
    var url = environment["SOURCEMAP_UPLOAD_URL"] ?? defaultURL
    sourcemapEndpointPath = environment["NEWRELIC_SOURCEMAP_ENDPOINT"] ?? "v1/react-native/sourcemaps"

    // Determine source map path
    let derivedFileDir = environment["DERIVED_FILE_DIR"] ?? ""
    let sourcemapPath = environment["SOURCEMAP_PATH"] ?? "\(derivedFileDir)/main.jsbundle.map"

    if debug {
        print("========== Configuration = \(configuration)")
        print("========== Platform = \(platformName ?? "NOT FOUND")")
        print("========== Source Map Path = \(sourcemapPath)")
        print("========== URL = \(url)")
        print("========== API Key = \(apiKey.prefix(10))...")
    }

    // Check if source map exists
    guard fileManager.fileExists(atPath: sourcemapPath) else {
        print("Error: Source map not found at: \(sourcemapPath)")
        print("Make sure React Native bundling completed successfully and SOURCEMAP_OUTPUT is set.")
        print("This script should run AFTER the 'Bundle React Native code and images' build phase.")
        exit(1)
    }

    print("New Relic: Found source map at: \(sourcemapPath)")

    // Check file size
    do {
        let attributes = try fileManager.attributesOfItem(atPath: sourcemapPath)
        if let fileSize = attributes[.size] as? UInt64 {
            let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0
            print("New Relic: Source map size: \(String(format: "%.2f", fileSizeMB))MB")

            if fileSize > maxFileSizeBytes {
                print("Error: Source map exceeds 200MB limit")
                print("Consider enabling minification or using code splitting")
                exit(1)
            }
        }
    } catch {
        print("Warning: Could not determine file size: \(error)")
    }

    // Extract version info from Info.plist
    guard let infoplistPath = environment["INFOPLIST_PATH"],
          let builtProductsDir = environment["BUILT_PRODUCTS_DIR"] else {
        print("Error: Could not find Info.plist path from environment")
        exit(1)
    }

    let builtInfoPlistPath = "\(builtProductsDir)/\(infoplistPath)"

    guard let infoPlist = NSDictionary(contentsOfFile: builtInfoPlistPath) else {
        print("Error: Could not read Info.plist at: \(builtInfoPlistPath)")
        exit(1)
    }

    guard let appVersion = infoPlist["CFBundleShortVersionString"] as? String else {
        print("Error: Could not read CFBundleShortVersionString from Info.plist")
        exit(1)
    }

    guard let buildNumber = infoPlist["CFBundleVersion"] as? String else {
        print("Error: Could not read CFBundleVersion from Info.plist")
        exit(1)
    }

    // Generate JS Bundle ID: appVersion.buildNumber-shortUUID
    // Example: "1.2.3.42-a1b2c3d4"
    let shortUUID = String(UUID().uuidString.prefix(8).lowercased())
    var jsBundleId = "\(appVersion).\(buildNumber)-\(shortUUID)"

    // Allow optional override via environment variable
    if let customId = environment["NEWRELIC_JS_BUNDLE_ID"], !customId.isEmpty {
        jsBundleId = customId
        if debug { print("Using custom JS Bundle ID from environment") }
    }

    let sourcemapName = "main.jsbundle.map"

    print("New Relic: Upload metadata:")
    print("  App Version: \(appVersion)")
    print("  JS Bundle ID: \(jsBundleId)")
    print("  Source Map Name: \(sourcemapName)")
    if debug {
        print("  App Token: \(appToken.prefix(10))...")
    }

    // Upload source map
    let uploadURL = "\(url)/\(sourcemapEndpointPath)"
    print("New Relic: Uploading to: \(uploadURL)")

    do {
        try uploadSourceMap(
            apiKey: apiKey,
            appToken: appToken,
            url: uploadURL,
            sourcemapPath: sourcemapPath,
            jsBundleId: jsBundleId,
            appVersionId: appVersion,
            sourcemapName: sourcemapName
        )
        print("New Relic: ✓ Source map uploaded successfully!")
        exit(0)
    } catch {
        print("Error: Source map upload failed: \(error)")
        exit(1)
    }
}

// MARK: - Helper Functions

func uploadSourceMap(
    apiKey: String,
    appToken: String,
    url: String,
    sourcemapPath: String,
    jsBundleId: String,
    appVersionId: String,
    sourcemapName: String
) throws {

    guard let uploadURL = URL(string: url) else {
        throw SourceMapToolError.invalidConfiguration
    }

    // Create multipart form data
    let boundary = "Boundary-\(UUID().uuidString)"
    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
    request.setValue(appToken, forHTTPHeaderField: "X-APP-LICENSE-KEY")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()

    // Add text fields
    let textFields = [
        "jsBundleId": jsBundleId,
        "appVersionId": appVersionId,
        "sourcemapName": sourcemapName
    ]

    for (key, value) in textFields {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    // Add source map file
    guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: sourcemapPath)) else {
        throw SourceMapToolError.sourceMapNotFound
    }

    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"sourcemap\"; filename=\"\(sourcemapName)\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
    body.append(fileData)
    body.append("\r\n".data(using: .utf8)!)
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

    request.httpBody = body

    if debug {
        print("Request URL: \(uploadURL)")
        print("Request body size: \(body.count) bytes")
    }

    // Perform synchronous upload
    let semaphore = DispatchSemaphore(value: 0)
    var uploadError: Error?
    var httpStatusCode: Int = 0

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }

        if let error = error {
            uploadError = error
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            uploadError = SourceMapToolError.failedToUpload
            return
        }

        httpStatusCode = httpResponse.statusCode

        if debug {
            print("Response status code: \(httpStatusCode)")
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response body: \(responseString)")
            }
        }

        guard (200...299).contains(httpStatusCode) else {
            if httpStatusCode == 401 {
                print("Error: Unauthorized (HTTP 401)")
                print("The API key is valid, but the app token belongs to a different account")
                print("Please ensure the API key and app token are from the same New Relic account")
            } else if httpStatusCode == 403 {
                print("Error: Forbidden (HTTP 403)")
                print("The API key doesn't have the required capability")
                print("Please check your New Relic Ingest API Key at https://one.newrelic.com/api-keys")
            } else if httpStatusCode == 404 {
                print("Error: Not Found (HTTP 404)")
                print("The app token (X-APP-LICENSE-KEY) is invalid or doesn't exist")
                print("Please verify your New Relic app token in Info.plist")
            } else if httpStatusCode == 413 {
                print("Error: Payload too large (HTTP 413)")
                print("Source map file exceeds the 200MB limit")
            } else {
                print("Error: Upload failed with HTTP status: \(httpStatusCode)")
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }

            uploadError = SourceMapToolError.failedToUpload
            return
        }
    }

    task.resume()
    semaphore.wait()

    if let error = uploadError {
        throw error
    }
}

// MARK: - Extensions

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
