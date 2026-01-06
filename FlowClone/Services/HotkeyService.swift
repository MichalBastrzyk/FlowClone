//
//  HotkeyService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import ApplicationServices
import AppKit

final class HotkeyService {
    static let shared = HotkeyService()

    // MARK: - Callbacks

    var onHotkeyDown: ((Date) -> Void)?
    var onHotkeyUp: ((Date) -> Void)?

    // MARK: - Private Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHotkeyDown = false
    private var debouncing = false

    private let fnKeyCode: UInt32 = 63 // Globe/Fn key
    private var fallbackHotkey: HotkeyConfig?

    private init() {
        setupEventTap()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Setup

    private func setupEventTap() {
        Logger.shared.info("[HotkeyService] Setting up event tap...")

        // Check permissions first
        let permissions = PermissionsService.shared
        permissions.refreshInputMonitoringPermission()

        Logger.shared.info("[HotkeyService] Input Monitoring permission: \(permissions.inputMonitoringPermissionStatus)")
        Logger.shared.info("[HotkeyService] Accessibility permission: \(permissions.accessibilityPermissionStatus)")

        if permissions.inputMonitoringPermissionStatus != .granted && permissions.accessibilityPermissionStatus != .granted {
            Logger.shared.error("[HotkeyService] ❌ Cannot create event tap - neither Input Monitoring nor Accessibility permission granted")
            Logger.shared.error("[HotkeyService] Please grant permissions in System Settings > Privacy & Security")
            return
        }

        // Create event tap for key events
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        Logger.shared.debug("[HotkeyService] Creating event tap with mask: \(eventMask)")

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                return HotkeyService.eventCallback(
                    proxy: proxy,
                    type: type,
                    event: event,
                    refcon: refcon
                )
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.shared.error("[HotkeyService] ❌ Failed to create event tap - permissions denied or system error")
            Logger.shared.error("[HotkeyService] Try granting 'Input Monitoring' permission in System Settings")
            return
        }

        eventTap = tap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        self.runLoopSource = runLoopSource
        CGEvent.tapEnable(tap: tap, enable: true)

        Logger.shared.info("[HotkeyService] ✅ Event tap created successfully")
        Logger.shared.info("[HotkeyService] Listening for Fn/Globe key (code 63) or fallback hotkey")
        Logger.shared.info("[HotkeyService] Try pressing your hotkey now...")
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            eventTap = nil
            runLoopSource = nil
        }
    }

    func setFallbackHotkey(_ config: HotkeyConfig?) {
        self.fallbackHotkey = config
        Logger.shared.info("Fallback hotkey set: \(config?.displayName ?? "none")")
    }

    // MARK: - Event Callback

    private static func eventCallback(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }

        let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()

        switch type {
        case .keyDown:
            service.handleKeyDown(event: event)

        case .keyUp:
            service.handleKeyUp(event: event)

        case .flagsChanged:
            service.handleFlagsChanged(event: event)

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }

    private func handleKeyDown(event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        Logger.shared.debug("[HotkeyService] Key DOWN: keyCode=\(keyCode), flags=\(flags.rawValue)")

        // Check for fallback hotkey
        if let config = fallbackHotkey,
           keyCode == config.keyCode &&
           flagsMatches(flags: flags, modifiers: config.modifiers) {
            if !isHotkeyDown {
                isHotkeyDown = true
                Logger.shared.info("[HotkeyService] 🔥 HOTKEY DOWN (fallback: \(config.displayName))")
                onHotkeyDown?(Date())
            }
            return
        }

        // Check for Fn/Globe key
        if keyCode == fnKeyCode && !isHotkeyDown {
            isHotkeyDown = true
            Logger.shared.info("[HotkeyService] 🔥 HOTKEY DOWN (Fn/Globe key detected!)")
            onHotkeyDown?(Date())
        }
    }

    private func handleKeyUp(event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        Logger.shared.debug("[HotkeyService] Key UP: keyCode=\(keyCode), flags=\(flags.rawValue)")

        // Check for fallback hotkey
        if let config = fallbackHotkey,
           keyCode == config.keyCode &&
           flagsMatches(flags: flags, modifiers: config.modifiers) {
            if isHotkeyDown {
                isHotkeyDown = false
                Logger.shared.info("[HotkeyService] 🎹 HOTKEY UP (fallback: \(config.displayName))")
                onHotkeyUp?(Date())
            }
            return
        }

        // Check for Fn/Globe key
        if keyCode == fnKeyCode && isHotkeyDown {
            isHotkeyDown = false
            Logger.shared.info("[HotkeyService] 🎹 HOTKEY UP (Fn/Globe key)")
            onHotkeyUp?(Date())
        }
    }

    private func handleFlagsChanged(event: CGEvent) {
        // Handle modifier key changes
        let flags = event.flags
        let hasModifiers = !flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty

        // If we have a fallback hotkey with modifiers and they're released
        if isHotkeyDown && !hasModifiers {
            isHotkeyDown = false
            Logger.shared.debug("Hotkey UP (modifiers released)")
            onHotkeyUp?(Date())
        }
    }

    private func flagsMatches(flags: CGEventFlags, modifiers: NSEvent.ModifierFlags) -> Bool {
        let commandPressed = flags.contains(.maskCommand)
        let controlPressed = flags.contains(.maskControl)
        let optionPressed = flags.contains(.maskAlternate)
        let shiftPressed = flags.contains(.maskShift)

        let modifiersMatch = modifiers.contains(.command) == commandPressed &&
                             modifiers.contains(.control) == controlPressed &&
                             modifiers.contains(.option) == optionPressed &&
                             modifiers.contains(.shift) == shiftPressed

        return modifiersMatch
    }
}
