//
//  LaunchAtLoginService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import ServiceManagement

@Observable
final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private(set) var isEnabled: Bool

    private init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Control

    func enable() throws {
        Logger.shared.info("Enabling launch at login...")
        try SMAppService.mainApp.register()
        isEnabled = true
        Logger.shared.info("Launch at login enabled")
    }

    func disable() throws {
        Logger.shared.info("Disabling launch at login...")
        try SMAppService.mainApp.unregister()
        isEnabled = false
        Logger.shared.info("Launch at login disabled")
    }

    func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }
}
