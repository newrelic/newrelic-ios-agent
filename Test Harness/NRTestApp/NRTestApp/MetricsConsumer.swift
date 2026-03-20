//
//  MetricsConsumer.swift
//  NRTestApp
//
//  Created by Chris Dillard on 8/7/25.
//

import Foundation
import OSLog
import PerformanceSuite
import SwiftUI

extension UIHostingController: PerformanceTrackable {
    var performanceScreen: PerformanceScreen? {
        return (introspectRootView() as? PerformanceTrackable)?.performanceScreen
    }
}

class MetricsConsumer: PerformanceSuiteMetricsReceiver {

    let interop = UITestsHelper.isInTests ? UITestsInterop.Server() : nil
    private let metricsFileURL: URL

    init() {
        // Set up metrics file in Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.metricsFileURL = documentsPath.appendingPathComponent("performance_metrics.json")

        // Create empty array if file doesn't exist
        if !FileManager.default.fileExists(atPath: metricsFileURL.path) {
            saveMetrics([])
        }
    }

    func appRenderingMetricsReceived(metrics: RenderingMetrics) {
        log("App RenderingMetrics \(metrics)")
        interop?.send(message: Message.appFreezeTime(duration: metrics.freezeTime.milliseconds ?? -1))

        saveMetricToDisk([
            "type": "appRendering",
            "freezeTime": metrics.freezeTime.milliseconds ?? -1
        ])
    }

    func ttiMetricsReceived(metrics: TTIMetrics, screen: PerformanceScreen) {
        log("TTIMetrics \(screen) \(metrics)")
        interop?.send(message: Message.tti(duration: metrics.tti.milliseconds ?? -1, screen: screen.rawValue))

        saveMetricToDisk([
            "type": "tti",
            "screen": screen.rawValue,
            "tti": metrics.tti.milliseconds ?? -1
        ])
    }

    func renderingMetricsReceived(metrics: RenderingMetrics, screen: PerformanceScreen) {
        log("RenderingMetrics \(screen) \(metrics)")
        interop?.send(message: Message.freezeTime(duration: metrics.freezeTime.milliseconds ?? -1, screen: screen.rawValue))

        saveMetricToDisk([
            "type": "rendering",
            "screen": screen.rawValue,
            "freezeTime": metrics.freezeTime.milliseconds ?? -1
        ])
    }

    func screenIdentifier(for viewController: UIViewController) -> PerformanceScreen? {
        return (viewController as? PerformanceTrackable)?.performanceScreen
    }

    func watchdogTerminationReceived(_ data: WatchdogTerminationData) {
        log("WatchdogTermination reported")
        interop?.send(message: Message.watchdogTermination)

        saveMetricToDisk([
            "type": "watchdogTermination"
        ])
    }

    func viewControllerLeakReceived(viewController: UIViewController) {
        log("View controller leak \(viewController)")
        interop?.send(message: Message.memoryLeak)

        saveMetricToDisk([
            "type": "memoryLeak",
            "viewController": String(describing: type(of: viewController))
        ])
    }

    func startupTimeReceived(_ data: StartupTimeData) {
        log("Startup time received \(data.totalTime.milliseconds ?? 0) ms")
        interop?.send(message: Message.startupTime(duration: data.totalTime.milliseconds ?? -1))

        saveMetricToDisk([
            "type": "startupTime",
            "duration": data.totalTime.milliseconds ?? -1
        ])
    }

    func fragmentTTIMetricsReceived(metrics: TTIMetrics, fragment identifier: String) {
        log("fragmentTTIMetricsReceived \(identifier) \(metrics)")
        interop?.send(message: Message.fragmentTTI(duration: metrics.tti.milliseconds ?? -1, fragment: identifier))
    }

    func fatalHangReceived(info: HangInfo) {
        log("fatalHangReceived \(info)")
        interop?.send(message: Message.fatalHang)

        saveMetricToDisk([
            "type": "fatalHang",
            "duration": info.duration.milliseconds ?? -1
        ])
    }

    func nonFatalHangReceived(info: HangInfo) {
        log("nonFatalHangReceived \(info)")
        interop?.send(message: Message.nonFatalHang)

        saveMetricToDisk([
            "type": "nonFatalHang",
            "duration": info.duration.milliseconds ?? -1
        ])
    }

    func hangStarted(info: HangInfo) {
        log("hangStarted \(info)")
        interop?.send(message: Message.hangStarted)

        saveMetricToDisk([
            "type": "hangStarted",
            "duration": info.duration.milliseconds ?? -1
        ])
    }

    var hangThreshold: TimeInterval {
        return 3
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
    private let logger = Logger(subsystem: "com.booking.PerformanceApp", category: "MetricsConsumer")

    // MARK: - Disk Persistence

    private func saveMetricToDisk(_ metric: [String: Any]) {
        do {
            // Read existing metrics
            var metrics: [[String: Any]] = []
            if let data = try? Data(contentsOf: metricsFileURL),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                metrics = existing
            }

            // Append new metric with timestamp
            var metricWithTimestamp = metric
            metricWithTimestamp["timestamp"] = ISO8601DateFormatter().string(from: Date())
            metrics.append(metricWithTimestamp)

            // Write back to file
            let data = try JSONSerialization.data(withJSONObject: metrics, options: .prettyPrinted)
            try data.write(to: metricsFileURL)

            log("Saved metric to disk: \(metricsFileURL.path)")
        } catch {
            log("Error saving metric to disk: \(error)")
        }
    }

    private func saveMetrics(_ metrics: [[String: Any]]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: metrics, options: .prettyPrinted)
            try data.write(to: metricsFileURL)
        } catch {
            log("Error creating metrics file: \(error)")
        }
    }

    // MARK: - ViewControllerLoggingReceiver

    func onInit(screen: PerformanceScreen) {
        log("onInit \(screen)")
    }

    func onViewDidLoad(screen: PerformanceScreen) {
        log("onViewDidLoad \(screen)")
    }

    func onViewWillAppear(screen: PerformanceScreen) {
        log("onViewWillAppear \(screen)")
    }

    func onViewDidAppear(screen: PerformanceScreen) {
        log("onViewDidAppear \(screen)")
    }

    func onViewWillDisappear(screen: PerformanceScreen) {
        log("onViewWillDisappear \(screen)")
    }

    func onViewDidDisappear(screen: PerformanceScreen) {
        log("onViewDidDisappear \(screen)")
    }
}
