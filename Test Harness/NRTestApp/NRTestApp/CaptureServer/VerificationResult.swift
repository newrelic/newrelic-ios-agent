import Foundation

struct VerificationCheck: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let detail: String?
}

struct VerificationResult {
    let checks: [VerificationCheck]

    var passed: Bool { checks.allSatisfy(\.passed) }
    var failCount: Int { checks.filter { !$0.passed }.count }

    static func make(@CheckBuilder _ build: () -> [VerificationCheck]) -> VerificationResult {
        VerificationResult(checks: build())
    }
}

@resultBuilder
enum CheckBuilder {
    static func buildBlock(_ components: [VerificationCheck]...) -> [VerificationCheck] { components.flatMap { $0 } }
    static func buildExpression(_ check: VerificationCheck) -> [VerificationCheck] { [check] }
    static func buildExpression(_ checks: [VerificationCheck]) -> [VerificationCheck] { checks }
    static func buildOptional(_ component: [VerificationCheck]?) -> [VerificationCheck] { component ?? [] }
    static func buildEither(first component: [VerificationCheck]) -> [VerificationCheck] { component }
    static func buildEither(second component: [VerificationCheck]) -> [VerificationCheck] { component }
    static func buildArray(_ components: [[VerificationCheck]]) -> [VerificationCheck] { components.flatMap { $0 } }
}

func check(_ name: String, _ condition: @autoclosure () -> Bool, detail: String? = nil) -> VerificationCheck {
    let passed = condition()
    return VerificationCheck(name: name, passed: passed, detail: detail)
}
