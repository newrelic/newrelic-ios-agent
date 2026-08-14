import Foundation

// MARK: - ConnectConfig

/// Typed model of the /connect response body. All fields map 1-to-1 to the JSON the server
/// sends to the agent. Codable lets the UI edit the config as pretty-printed JSON and re-parse it.
///
/// `at_capture` ([Int, [Any]]) is a heterogeneous array that can't be expressed cleanly in
/// Swift's type system — it is injected separately by `toServerDict()`.
struct ConnectConfig: Codable {
    var serverTimestamp: Int = 1656525980
    var dataReportPeriod: Int = 60
    var reportMaxTransactionCount: Int = 1000
    var reportMaxTransactionAge: Int = 600
    var collectNetworkErrors: Bool = true
    var errorLimit: Int = 50
    var responseBodyLimit: Int = 2048
    var stackTraceLimit: Int = 100
    var dataToken: [Int] = [111111111, 222222222]
    var crossProcessId: String = "AAAAAAAAAAAAAAAAAAAAAA=="
    var encodingKey: String = "0000000000000000000000000000000000000000"
    var accountId: String = "1"
    var applicationId: String = "1"
    var entityGuid: String = "AAAAAAAAAAAAAAAAAAAAAA=="
    var configuration: Configuration = .init()

    struct Configuration: Codable {
        var sessionReplay: SessionReplay = .init()
        var logs: Logs = .init()

        enum CodingKeys: String, CodingKey {
            case sessionReplay = "session_replay"
            case logs
        }
    }

    struct SessionReplay: Codable {
        var enabled: Bool = true
        var samplingRate: Double = 100.0
        var errorSamplingRate: Double = 100.0
        var mode: String = "custom"
        var maskApplicationText: Bool = false
        var maskUserInputText: Bool = false
        var maskAllImages: Bool = false
        var maskAllUserTouches: Bool = false
        var customMaskingRules: [MaskingRule] = [
            .init(identifier: "tag",   type: "mask",   name: ["sensitiveField"]),
            .init(identifier: "class", type: "mask",   name: ["UITextField"]),
            .init(identifier: "class", type: "unmask", name: ["NRUnmaskedLabel"]),
        ]

        enum CodingKeys: String, CodingKey {
            case enabled, mode
            case samplingRate = "sampling_rate"
            case errorSamplingRate = "error_sampling_rate"
            case maskApplicationText = "mask_application_text"
            case maskUserInputText = "mask_user_input_text"
            case maskAllImages = "mask_all_images"
            case maskAllUserTouches = "mask_all_user_touches"
            case customMaskingRules = "custom_masking_rules"
        }
    }

    struct Logs: Codable {
        var enabled: Bool = true
        var level: String = "DEBUG"
        var samplingRate: Double = 100.0

        enum CodingKeys: String, CodingKey {
            case enabled, level
            case samplingRate = "sampling_rate"
        }
    }

    struct MaskingRule: Codable {
        var identifier: String
        var type: String
        var name: [String]
    }

    enum CodingKeys: String, CodingKey {
        case serverTimestamp = "server_timestamp"
        case dataReportPeriod = "data_report_period"
        case reportMaxTransactionCount = "report_max_transaction_count"
        case reportMaxTransactionAge = "report_max_transaction_age"
        case collectNetworkErrors = "collect_network_errors"
        case errorLimit = "error_limit"
        case responseBodyLimit = "response_body_limit"
        case stackTraceLimit = "stack_trace_limit"
        case dataToken = "data_token"
        case crossProcessId = "cross_process_id"
        case encodingKey = "encoding_key"
        case accountId = "account_id"
        case applicationId = "application_id"
        case entityGuid = "entity_guid"
        case configuration
    }
}

// MARK: - Helpers

extension ConnectConfig {
    static let `default` = ConnectConfig()

    /// Returns a [String: Any] dict ready to hand to HttpServer as the connect response body.
    /// Injects `at_capture` ([1, []]) which can't be round-tripped through Codable cleanly.
    func toServerDict() -> [String: Any] {
        let enc = JSONEncoder()
        guard let data = try? enc.encode(self),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return [:]
        }
        dict["at_capture"] = [1, []] as [Any]
        return dict
    }
}
