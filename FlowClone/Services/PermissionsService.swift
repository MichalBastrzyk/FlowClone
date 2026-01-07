//
//  PermissionsService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import AVFoundation
import ApplicationServices
import AppKit
import Observation

@Observable
final class PermissionsService {
    static let shared = PermissionsService()

    // MARK: - Published Properties

    private(set) var microphonePermissionStatus: PermissionStatus = .notDetermined

    private(set) var accessibilityPermissionStatus: PermissionStatus = .notDetermined

    private(set) var inputMonitoringPermissionStatus: PermissionStatus = .notDetermined

    var hasAllPermissions: Bool {
        microphonePermissionStatus == .granted &&
        (accessibilityPermissionStatus == .granted || inputMonitoringPermissionStatus == .granted)
    }

    var canRecordAudio: Bool {
        microphonePermissionStatus == .granted
    }

    var canUseHotkey: Bool {
        accessibilityPermissionStatus == .granted || inputMonitoringPermissionStatus == .granted
    }

    var canInjectText: Bool {
        accessibilityPermissionStatus == .granted
    }

    // MARK: - Init

    private init() {
        refreshAllPermissions()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Permission Checking

    @objc private func applicationDidBecomeActive() {
        refreshAllPermissions()
    }

    func refreshAllPermissions() {
        refreshMicrophonePermission()
        refreshAccessibilityPermission()
        refreshInputMonitoringPermission()
    }

    // MARK: - Microphone

    func refreshMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionStatus = PermissionStatus(from: status)
        Logger.shared.permissionChanged("Microphone", granted: microphonePermissionStatus == .granted)
    }

    func requestMicrophonePermission() async throws {
        let status = await AVCaptureDevice.requestAccess(for: .audio)

        await MainActor.run {
            microphonePermissionStatus = status ? .granted : .denied
            Logger.shared.permissionChanged("Microphone", granted: status)
        }

        if !status {
            throw PermissionError.microphoneDenied
        }
    }

    // MARK: - Accessibility

    func refreshAccessibilityPermission() {
        let status = AXIsProcessTrusted()
        accessibilityPermissionStatus = status ? .granted : .denied
        Logger.shared.permissionChanged("Accessibility", granted: status)
    }

    func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let status = AXIsProcessTrustedWithOptions(options as CFDictionary)
        _ = status // This triggers the prompt
        Logger.shared.info("Prompted for Accessibility permission")
    }

    // MARK: - Input Monitoring

    func refreshInputMonitoringPermission() {
        // Check if we have event tap access
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: { proxy, type, event, refcon in
                // Use passUnretained to avoid incrementing ref count (fixes memory leak)
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )

        if let tap = tap {
            inputMonitoringPermissionStatus = .granted
            CGEvent.tapEnable(tap: tap, enable: false)
            // Clean up the CFMachPort to prevent leak
            CFMachPortInvalidate(tap)
        } else {
            inputMonitoringPermissionStatus = .denied
        }

        Logger.shared.permissionChanged("Input Monitoring", granted: inputMonitoringPermissionStatus == .granted)
    }

    func promptForInputMonitoringPermission() {
        Logger.shared.info("User should be prompted for Input Monitoring permission")
        // The system will prompt when we try to create the event tap
    }
}

// MARK: - Supporting Types

enum PermissionStatus {
    case notDetermined
    case granted
    case denied

    init(from avStatus: AVAuthorizationStatus) {
        switch avStatus {
        case .notDetermined:
            self = .notDetermined
        case .authorized:
            self = .granted
        case .denied, .restricted:
            self = .denied
        @unknown default:
            self = .denied
        }
    }
}

enum PermissionError: LocalizedError {
    case microphoneDenied
    case accessibilityDenied
    case inputMonitoringDenied

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access is required to record audio"
        case .accessibilityDenied:
            return "Accessibility access is required for text injection"
        case .inputMonitoringDenied:
            return "Input monitoring access is required for global hotkey"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .microphoneDenied:
            return "Open System Settings > Privacy & Security > Microphone and enable FlowClone"
        case .accessibilityDenied:
            return "Open System Settings > Privacy & Security > Accessibility and enable FlowClone"
        case .inputMonitoringDenied:
            return "Open System Settings > Privacy & Security > Input Monitoring and enable FlowClone"
        }
    }
}
