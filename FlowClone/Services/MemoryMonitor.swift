//
//  MemoryMonitor.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation

/// Monitors memory usage and logs warnings if memory grows abnormally.
/// This is a diagnostic service to help detect memory leaks.
final class MemoryMonitor {
    static let shared = MemoryMonitor()

    private var monitoringTimer: Timer?
    private let warningThresholdMB: Double = 200  // Warn if > 200MB
    private let criticalThresholdMB: Double = 300  // Alert if > 300MB

    private init() {}

    // MARK: - Lifecycle

    func startMonitoring() {
        guard monitoringTimer == nil else { return }

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }

        Logger.shared.info("Memory monitor started (warning: \(Int(warningThresholdMB))MB, critical: \(Int(criticalThresholdMB))MB)")
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        Logger.shared.info("Memory monitor stopped")
    }

    // MARK: - Memory Checking

    private func checkMemoryUsage() {
        let memoryMB = getMemoryUsageMB()

        if memoryMB > criticalThresholdMB {
            Logger.shared.fault("⚠️ CRITICAL: Memory usage at \(Int(memoryMB))MB - potential leak detected")
        } else if memoryMB > warningThresholdMB {
            Logger.shared.error("⚠️ WARNING: Memory usage at \(Int(memoryMB))MB")
        } else {
            Logger.shared.debug("Memory usage: \(Int(memoryMB))MB")
        }
    }

    private func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Double(info.resident_size) / 1024 / 1024 : 0
    }
}
