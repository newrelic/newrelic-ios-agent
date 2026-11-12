//
//  AppLog.swift
//  ExpensesTracker
//
//  One logging call for the app's own diagnostic output, separate from anything it reports to New
//  Relic.
//
//  It goes through NSLog rather than `print` deliberately. `print` writes to stdout, which is only
//  visible when the process is attached to a terminal or to Xcode — launch the app any other way (a
//  detached `simctl launch`, a UI-automation harness, LambdaTest) and everything this app has to say
//  silently goes nowhere. NSLog reaches the unified log instead, so all of these see it:
//
//      xcrun simctl spawn <udid> log stream --predicate 'process == "ExpensesTracker"'
//      Console.app
//      the Xcode console
//
//  Matches Test Harness/HomeSearch's appLog for the same reasons.
//

import Foundation

func appLog(_ message: String) {
    NSLog("%@", message)
}
