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
    private var metricsLabel: UILabel?
    private var resourceMonitorTimer: Timer?

    init() {
        // Set up metrics file in Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.metricsFileURL = documentsPath.appendingPathComponent("performance_metrics.json")

        // Create empty array if file doesn't exist
        if !FileManager.default.fileExists(atPath: metricsFileURL.path) {
            saveMetrics([])
        }

        // Always create hidden label for Appium tests (for now)
        setupMetricsLabel()

        // Start monitoring memory/CPU for performance testing
        startResourceMonitoring()
    }

    deinit {
        resourceMonitorTimer?.invalidate()
    }

    private func setupMetricsLabel() {
        // Delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let label = UILabel()
            label.accessibilityIdentifier = "performance_metrics_json"
            label.numberOfLines = 0
            label.text = "[]"  // Start with empty array
            label.frame = CGRect(x: -1000, y: -1000, width: 10, height: 10)  // Off-screen
            label.alpha = 0.01  // Nearly invisible
            label.font = UIFont.systemFont(ofSize: 8)

            // Try multiple ways to add the label
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                window.addSubview(label)
                self.metricsLabel = label
                NSLog("✅ Metrics label created and added to window")
            } else if let window = UIApplication.shared.windows.first {
                window.addSubview(label)
                self.metricsLabel = label
                NSLog("✅ Metrics label created and added to first window")
            } else if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                rootVC.view.addSubview(label)
                self.metricsLabel = label
                NSLog("✅ Metrics label created and added to root view controller")
            } else {
                NSLog("❌ Failed to find a place to add metrics label")
            }
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

            // Update UI label for Appium tests
            if let label = metricsLabel {
                if let jsonData = try? JSONSerialization.data(withJSONObject: metrics, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    DispatchQueue.main.async {
                        label.text = jsonString
                        NSLog("✅ Updated metrics label with %d metrics (%.1f KB)", metrics.count, Double(jsonString.count) / 1024.0)
                    }
                }
            } else {
                NSLog("⚠️ Metrics label is nil, cannot update UI")
            }
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

    // MARK: - Resource Monitoring (Memory & CPU)

    private func startResourceMonitoring() {
        // Sample memory/CPU every 2 seconds during performance tests
        // MUST run on main thread for timer to fire properly
        DispatchQueue.main.async { [weak self] in
            self?.resourceMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.captureResourceMetrics()
            }
            NSLog("🔄 Resource monitoring timer started")
        }
    }

    private func captureResourceMetrics() {
        let memoryMB = getMemoryUsage()
        let cpuPercent = getCPUUsage()

        let metrics: [String: Any] = [
            "type": "resourceUsage",
            "memoryMB": memoryMB,
            "cpuPercent": cpuPercent
        ]

        NSLog("📊 Captured resources: Memory=%.2f MB, CPU=%.2f%%", memoryMB, cpuPercent)
        saveMetricToDisk(metrics)
    }

    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0
    }

    private func getCPUUsage() -> Double {
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        guard threadsResult == KERN_SUCCESS, let threads = threadsList else {
            return 0
        }

        var totalCPU = 0.0
        for index in 0..<Int(threadsCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }

            if infoResult == KERN_SUCCESS {
                let cpuUsage = Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                totalCPU += cpuUsage
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))

        return totalCPU
    }
}
