//
//  CrashTestSwiftUIView.swift
//  NRTestApp
//
//  A menu of Swift-language trap / signal / memory crashes for validating
//  New Relic crash reporting. Every row crashes the app immediately on tap.
//
//  NOTE: New Relic records a crash and uploads it on the NEXT launch, and the
//  Xcode debugger intercepts signals first. To validate NR capture, run the app
//  detached from the debugger (or continue past it), let it die, then relaunch.
//

import SwiftUI
import Foundation
import NewRelic

struct CrashTestSwiftUIView: View {

    private enum DemoError: Error { case boom }

    var body: some View {
        List {
            Section {
                Text("⚠️ Each row crashes the app instantly. New Relic uploads the crash on the NEXT launch — run detached from the Xcode debugger, let it die, then relaunch.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Swift runtime traps") {
                crashButton("Force-unwrap nil optional", "Unexpectedly found nil") {
                    _ = Self.alwaysNil()!
                }
                crashButton("Array index out of range", "Fatal error: Index out of range") {
                    let array = Self.makeArray()
                    _ = array[10]
                }
                crashButton("fatalError()", "Swift fatalError") {
                    fatalError("Intentional fatalError from CrashTestSwiftUIView")
                }
                crashButton("preconditionFailure()", "Swift precondition") {
                    preconditionFailure("Intentional preconditionFailure")
                }
                crashButton("assertionFailure()", "Debug builds only") {
                    assertionFailure("Intentional assertionFailure")
                }
                crashButton("try! on a throwing call", "Fatal error while unwrapping try!") {
                    _ = try! Self.throwing()
                }
            }

            Section("Arithmetic traps") {
                crashButton("Integer overflow", "Int.max + 1") {
                    var value = Int.max
                    // XCODE WONT ALLOW IT
                    //value += 1
                    _ = value
                }
                crashButton("Integer divide by zero", "Division by zero") {
                    let zero = Self.makeZero()
                    _ = 100 / zero
                }
            }

            Section("Signals & memory") {
                crashButton("Stack overflow", "Infinite recursion · SIGSEGV") {
                    _ = Self.recurse(0)
                }
                crashButton("Bad memory access", "Write to 0x1 · EXC_BAD_ACCESS") {
                    let pointer = UnsafeMutablePointer<Int>(bitPattern: 0x1)!
                    pointer.pointee = 42
                }
                crashButton("abort()", "SIGABRT") {
                    abort()
                }
                crashButton("Raise SIGILL", "Illegal instruction") {
                    kill(getpid(), SIGILL)
                }
                crashButton("Raise SIGTRAP", "Trace trap") {
                    kill(getpid(), SIGTRAP)
                }
                crashButton("Raise SIGFPE", "Floating-point exception") {
                    kill(getpid(), SIGFPE)
                }
            }
        }
        .navigationTitle("SwiftUI Crashes")
        .NRTrackView(name: "CrashTestSwiftUIView")
    }

    // MARK: - Row builder

    private func crashButton(_ title: String, _ detail: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityIdentifier("crash-\(title)")
    }

    // MARK: - Opaque helpers
    // These keep the compiler from constant-folding the crash away at build time.

    private static func alwaysNil() -> Int? { nil }
    private static func makeArray() -> [Int] { Array(0..<3) }
    private static func makeZero() -> Int { Int("0")! }
    private static func throwing() throws -> Int { throw DemoError.boom }
    private static func recurse(_ n: Int) -> Int {
        let next = recurse(n + 1)
        return next + n // non-tail call so the optimizer can't turn it into a loop
    }
}

struct CrashTestSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        CrashTestSwiftUIView()
    }
}
