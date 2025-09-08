import SwiftUI
import Combine
#if canImport(XCTest)
import XCTest
#else
public struct XCTestExpectation {
    public let description: String
    public func fulfill() { }
}

private func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) { }
#endif
@MainActor
@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public protocol InspectionEmissary: AnyObject, Sendable {

    associatedtype V
    var notice: PassthroughSubject<UInt, Never> { get }
    var callbacks: [UInt: (V) -> Void] { get set }
}

// MARK: - InspectionEmissary for View

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension InspectionEmissary where V: View {
    
    typealias ViewInspection = @MainActor @Sendable (InspectableView<ViewType.View<V>>) async throws -> Void
    
    @discardableResult
    func inspect(after delay: TimeInterval = 0,
                 function: String = #function, file: StaticString = #file, line: UInt = #line,
                 _ inspection: @escaping ViewInspection
    ) -> XCTestExpectation {
        return inspect(after: delay, function: function, file: file, line: line) { view in
            let unwrapped = try view.inspect(function: function)
                .asInspectableView(ofType: ViewType.View<V>.self)
            return try await inspection(unwrapped)
        }
    }
    
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    func inspect(after delay: SuspendingClock.Duration = .seconds(0),
                 function: String = #function, file: StaticString = #file, line: UInt = #line,
                 _ inspection: @escaping ViewInspection
    ) async throws {
        return try await inspect(after: delay, function: function, file: file, line: line) { view in
            let unwrapped = try view.inspect(function: function)
                .asInspectableView(ofType: ViewType.View<V>.self)
            return try await inspection(unwrapped)
        }
    }
    
    @discardableResult
    func inspect<P>(onReceive publisher: P,
                    after delay: TimeInterval = 0,
                    function: String = #function, file: StaticString = #file, line: UInt = #line,
                    _ inspection: @escaping ViewInspection
    ) -> XCTestExpectation where P: Publisher, P.Failure == Never {
        return inspect(onReceive: publisher, after: delay, function: function, file: file, line: line) { view in
            let unwrapped = try view.inspect(function: function)
                .asInspectableView(ofType: ViewType.View<V>.self)
            return try await inspection(unwrapped)
        }
    }
    
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    func inspect<P>(onReceive publisher: P,
                    after delay: SuspendingClock.Duration = .seconds(0),
                    function: String = #function, file: StaticString = #file, line: UInt = #line,
                    _ inspection: @escaping ViewInspection
    ) async throws where P: Publisher {
        return try await inspect(onReceive: publisher, after: delay, function: function, file: file, line: line) { view in
            let unwrapped = try view.inspect(function: function)
                .asInspectableView(ofType: ViewType.View<V>.self)
            return try await inspection(unwrapped)
        }
    }
}

// MARK: - InspectionEmissary for ViewModifier

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension InspectionEmissary where V: ViewModifier {
    
    typealias ViewModifierInspection = @MainActor @Sendable (InspectableView<ViewType.ViewModifier<V>>) async throws -> Void
    
    @discardableResult
    func inspect(after delay: TimeInterval = 0,
                 function: String = #function, file: StaticString = #file, line: UInt = #line,
                 _ inspection: @escaping ViewModifierInspection
    ) -> XCTestExpectation {
        return inspect(after: delay, function: function, file: file, line: line) { view in
            return try await inspection(try view.inspect(function: function))
        }
    }
    
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    func inspect(after delay: SuspendingClock.Duration = .seconds(0),
                 function: String = #function, file: StaticString = #file, line: UInt = #line,
                 _ inspection: @escaping ViewModifierInspection
    ) async throws {
        return try await inspect(after: delay, function: function, file: file, line: line) { view in
            return try await inspection(try view.inspect(function: function))
        }
    }
    
    @discardableResult
    func inspect<P>(onReceive publisher: P,
                    after delay: TimeInterval = 0,
                    function: String = #function, file: StaticString = #file, line: UInt = #line,
                    _ inspection: @escaping ViewModifierInspection
    ) -> XCTestExpectation where P: Publisher, P.Failure == Never {
        return inspect(onReceive: publisher, after: delay, function: function, file: file, line: line) { view in
            return try await inspection(try view.inspect(function: function))
        }
    }
    
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    func inspect<P>(onReceive publisher: P,
                    after delay: SuspendingClock.Duration = .seconds(0),
                    function: String = #function, file: StaticString = #file, line: UInt = #line,
                    _ inspection: @escaping ViewModifierInspection
    ) async throws where P: Publisher {
        return try await inspect(onReceive: publisher, after: delay, function: function, file: file, line: line) { view in
            return try await inspection(try view.inspect(function: function))
        }
    }
}

// MARK: - Private

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
private extension InspectionEmissary {
    
    typealias SubjectInspection = @MainActor @Sendable (_ subject: V) async throws -> Void
    
    func inspect(after delay: TimeInterval,
                 function: String, file: StaticString, line: UInt,
                 inspection: @escaping SubjectInspection
    ) -> XCTestExpectation {
        let exp = XCTestExpectation(description: "Inspection at line \(line)")
        setup(inspection: inspection, expectation: exp, function: function, file: file, line: line)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak notice] in
            notice?.send(line)
        }
        return exp
    }
    
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    func inspect(after delay: SuspendingClock.Duration,
                 function: String, file: StaticString, line: UInt,
                 inspection: @escaping SubjectInspection
    ) async throws {
        try await setup(inspection: inspection, delay: delay, function: function, file: file, line: line)
    }
    
    func inspect<P>(onReceive publisher: P,
                    after delay: TimeInterval,
                    function: String, file: StaticString, line: UInt,
                    inspection: @escaping SubjectInspection
    ) -> XCTestExpectation where P: Publisher, P.Failure == Never {
        let exp = XCTestExpectation(description: "Inspection at line \(line)")
        setup(inspection: inspection, expectation: exp, function: function, file: file, line: line)
        var subscription: AnyCancellable?
        _ = subscription
        subscription = publisher.sink { [weak notice] _ in
            subscription = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak notice] in
                notice?.send(line)
            }
        }
        return exp
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    func inspect<P>(onReceive publisher: P,
                    after delay: SuspendingClock.Duration,
                    function: String, file: StaticString, line: UInt,
                    inspection: @escaping SubjectInspection
    ) async throws where P: Publisher {
        // This simply awaits for the first value from the publisher:
        for try await _ in publisher.values.map({ _ in 0 }) { break }
        try await setup(inspection: inspection, delay: delay, function: function, file: file, line: line)
    }
    
    func setup(inspection: @escaping SubjectInspection,
               expectation: XCTestExpectation,
               function: String, file: StaticString, line: UInt) {
        callbacks[line] = { view in
            Task { @MainActor in
                do {
                    try await inspection(view)
                } catch {
                    XCTFail("\(error.localizedDescription)", file: file, line: line)
                }
                if self.callbacks.isEmpty {
                    ViewHosting.expel(function: function)
                }
                expectation.fulfill()
            }
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    func setup(inspection: @escaping SubjectInspection,
               delay: SuspendingClock.Duration,
               function: String, file: StaticString, line: UInt) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                callbacks[line] = { view in
                    Task { @MainActor in
                        do {
                            continuation.resume(returning: try await inspection(view))
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                let clock = SuspendingClock()
                try await clock.sleep(until: clock.now + delay)
                notice.send(line)
            }
        }
    }
}

// MARK: - on keyPath inspection

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension View {
    @discardableResult
    mutating func on(_ keyPath: WritableKeyPath<Self, ((Self) -> Void)?>,
                     function: String = #function, file: StaticString = #file, line: UInt = #line,
                     perform: @escaping ((InspectableView<ViewType.View<Self>>) throws -> Void)
    ) -> XCTestExpectation {
        let injector = Inspector.CallbackInjector(value: self, function: function, line: line, keyPath: keyPath) { body in
            body.inspect(function: function, file: file, line: line, inspection: perform)
        }
        self = injector.value
        return injector.expectation
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension ViewModifier {
    @discardableResult
    mutating func on(_ keyPath: WritableKeyPath<Self, ((Self) -> Void)?>,
                     function: String = #function, file: StaticString = #file, line: UInt = #line,
                     perform: @escaping ((InspectableView<ViewType.ViewModifier<Self>>) throws -> Void)
    ) -> XCTestExpectation {
        let injector = Inspector.CallbackInjector(value: self, function: function, line: line, keyPath: keyPath) { body in
            body.inspect(function: function, file: file, line: line, inspection: perform)
        }
        self = injector.value
        return injector.expectation
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
private extension Inspector {

    @MainActor
    final class CallbackInjector<T> {
        var value: T
        let keyPath: WritableKeyPath<T, ((T) -> Void)?>
        let inspection: (T) -> Void
        let expectation: XCTestExpectation

        init(value: T, function: String, line: UInt,
             keyPath: WritableKeyPath<T, ((T) -> Void)?>,
             inspection: @escaping (T) -> Void) {
            self.value = value
            self.keyPath = keyPath
            self.inspection = inspection
            let description = Inspector.typeName(value: value) + " callback at line #\(line)"
            let expectation = XCTestExpectation(description: description)
            self.expectation = expectation
            self.value[keyPath: keyPath] = { body in
                Task { @MainActor in
                    inspection(body)
                    ViewHosting.expel(function: function)
                    expectation.fulfill()
                }
            }
        }
    }
}
