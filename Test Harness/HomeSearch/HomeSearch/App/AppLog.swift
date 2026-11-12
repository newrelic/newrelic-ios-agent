//
//  AppLog.swift
//  HomeSearch
//
//  One logging call for the app's diagnostic output.
//
//  It goes through NSLog rather than `print` deliberately. `print` writes to stdout, which is only
//  visible when the process is attached to a terminal or to Xcode — launch the app any other way (a
//  detached `simctl launch`, a UI-automation harness) and everything this app has to say silently
//  goes nowhere. Since the point of HomeSearch is reporting what the agent recorded, output that
//  only survives under one launch method is not good enough.
//
//  NSLog reaches the unified log, so all of these see it:
//
//      xcrun simctl spawn <udid> log stream --predicate 'process == "HomeSearch"'
//      Console.app
//      the Xcode console
//

import Foundation

func appLog(_ message: String) {
    NSLog("%@", message)
}
