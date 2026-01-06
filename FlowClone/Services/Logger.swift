//
//  Logger.swift
//  FlowClone
//
//  Created by Claude
//

import OSLog

final class Logger {
    static let shared = Logger()

    private let logger = OSLog(subsystem: "com.michalbastrzyk.FlowClone", category: "FlowClone")

    private init() {}

    func debug(_ message: String, function: String = #function, file: String = #file) {
        os_log("%{public}@", log: logger, type: .debug, message)
    }

    func info(_ message: String, function: String = #function, file: String = #file) {
        os_log("%{public}@", log: logger, type: .info, message)
    }

    func error(_ message: String, function: String = #function, file: String = #file) {
        os_log("%{public}@", log: logger, type: .error, message)
    }

    func fault(_ message: String, function: String = #function, file: String = #file) {
        os_log("%{public}@", log: logger, type: .fault, message)
    }

    // State transitions
    func stateTransition(_ from: String, to: String, event: String) {
        info("[State] \(from) -> \(to) (event: \(event))")
    }

    // Permission changes
    func permissionChanged(_ permission: String, granted: Bool) {
        info("[Permission] \(permission): \(granted ? "granted" : "denied")")
    }
}
