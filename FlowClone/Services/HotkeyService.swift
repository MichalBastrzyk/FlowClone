//
//  HotkeyService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import ApplicationServices
import AppKit
import CoreGraphics

final class HotkeyService {
    static let shared = HotkeyService()

    // MARK: - Enums

    enum Modifier: Hashable {
        case shift
        case control
        case option
        case command
        case fn

        var displayName: String {
            switch self {
            case .shift: return "Shift"
            case .control: return "Control"
            case .option: return "Option"
            case .command: return "Command"
            case .fn: return "Fn"
            }
        }

        var cgFlag: CGEventFlags {
            switch self {
            case .shift: return .maskShift
            case .control: return .maskControl
            case .option: return .maskAlternate
            case .command: return .maskCommand
            case .fn: return .maskSecondaryFn
            }
        }
    }

    struct ModifierSnapshot: Equatable {
        let down: Set<Modifier>
    }

    // MARK: - Callbacks

    var onHotkeyDown: ((Date) -> Void)?
    var onHotkeyUp: ((Date) -> Void)?

    var onModifierDown: ((Modifier) -> Void)?
    var onModifierUp: ((Modifier) -> Void)?
    var onModifiersChanged: ((Set<Modifier>) -> Void)? // For UI feedback

    // MARK: - Private Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHotkeyDown = false
    private var lastSnapshot = ModifierSnapshot(down: [])

    private var fallbackHotkey: HotkeyConfig?

    private init() {
        start()
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func start() {
        stop()

        Logger.shared.info("[HotkeyService] Setting up event tap...")

        // Check permissions first
        let permissions = PermissionsService.shared
        permissions.refreshInputMonitoringPermission()
        permissions.refreshAccessibilityPermission()

        Logger.shared.info("[HotkeyService] Input Monitoring permission: \(permissions.inputMonitoringPermissionStatus)")
        Logger.shared.info("[HotkeyService] Accessibility permission: \(permissions.accessibilityPermissionStatus)")

        if permissions.inputMonitoringPermissionStatus != .granted && permissions.accessibilityPermissionStatus != .granted {
            Logger.shared.error("[HotkeyService] ❌ Cannot create event tap - neither Input Monitoring nor Accessibility permission granted")
            Logger.shared.error("[HotkeyService] Please grant permissions in System Settings > Privacy & Security")
            return
        }

        // ONLY listen for modifier transitions (no regular keys)
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)

        Logger.shared.debug("[HotkeyService] Creating event tap with mask: \(eventMask)")

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
            return service.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            Logger.shared.error("[HotkeyService] ❌ Failed to create event tap - permissions denied or system error")
            Logger.shared.error("[HotkeyService] Try granting 'Input Monitoring' or 'Accessibility' permission in System Settings")
            return
        }

        eventTap = tap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        CGEvent.tapEnable(tap: tap, enable: true)

        Logger.shared.info("[HotkeyService] ✅ Event tap created successfully")
        Logger.shared.info("[HotkeyService] Listening for modifier keys (Shift/Ctrl/Option/Cmd/Fn)")
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        runLoopSource = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        lastSnapshot = ModifierSnapshot(down: [])
    }

    func setFallbackHotkey(_ config: HotkeyConfig?) {
        self.fallbackHotkey = config
        Logger.shared.info("Fallback hotkey set: \(config?.displayName ?? "none")")
    }

    // MARK: - Event Handler

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if the system disables the tap
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Logger.shared.info("[HotkeyService] ⚠️ Event tap disabled, re-enabling...")
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .flagsChanged:
            handleFlagsChanged(event)

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Flags Changed Handler

    private func handleFlagsChanged(_ event: CGEvent) {
        let flags = event.flags
        var down = Set<Modifier>()

        if flags.contains(.maskShift) { down.insert(.shift) }
        if flags.contains(.maskControl) { down.insert(.control) }
        if flags.contains(.maskAlternate) { down.insert(.option) }
        if flags.contains(.maskCommand) { down.insert(.command) }
        if flags.contains(.maskSecondaryFn) { down.insert(.fn) }

        let newSnapshot = ModifierSnapshot(down: down)
        emitDiff(from: lastSnapshot, to: newSnapshot)
        lastSnapshot = newSnapshot
    }

    private func emitDiff(from old: ModifierSnapshot, to new: ModifierSnapshot) {
        let wentDown = new.down.subtracting(old.down)
        let wentUp = old.down.subtracting(new.down)

        for m in wentDown {
            // Logger.shared.info("[HotkeyService] 🔥 MODIFIER DOWN: \(m.displayName)") // Muted
            onModifierDown?(m)
        }

        for m in wentUp {
            // Logger.shared.info("[HotkeyService] 🎹 MODIFIER UP: \(m.displayName)") // Muted
            onModifierUp?(m)
        }

        // Notify UI of current modifier state
        onModifiersChanged?(new.down)

        // Check if current state matches our hotkey config
        checkHotkeyTrigger(currentModifiers: new.down, justPressed: wentDown, justReleased: wentUp)
    }

    private func checkHotkeyTrigger(currentModifiers: Set<Modifier>, justPressed: Set<Modifier>, justReleased: Set<Modifier>) {
        guard let config = fallbackHotkey, config.isModifierOnly else {
            return
        }

        // Convert config.modifiers to Set<Modifier>
        let requiredModifiers = configToModifierSet(config)

        // Check if all required modifiers are pressed
        let isHotkeyPressed = requiredModifiers.isSubset(of: currentModifiers)

        if isHotkeyPressed && !isHotkeyDown {
            // All required modifiers are down
            isHotkeyDown = true
            Logger.shared.info("[HotkeyService] ✅ HOTKEY TRIGGERED: \(config.displayName)")
            triggerHotkeyDown()
        } else if !isHotkeyPressed && isHotkeyDown {
            // At least one required modifier was released
            isHotkeyDown = false
            Logger.shared.info("[HotkeyService] 🔻 HOTKEY RELEASED: \(config.displayName)")
            triggerHotkeyUp()
        }
    }

    private func configToModifierSet(_ config: HotkeyConfig) -> Set<Modifier> {
        var modifiers: Set<Modifier> = []

        if config.modifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        if config.modifiers.contains(.control) {
            modifiers.insert(.control)
        }
        if config.modifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if config.modifiers.contains(.command) {
            modifiers.insert(.command)
        }

        // Fn is detected separately - if it's a modifier-only config with no standard modifiers, assume Fn
        if modifiers.isEmpty && config.isModifierOnly {
            modifiers.insert(.fn)
        }

        return modifiers
    }

    private func triggerHotkeyDown() {
        isHotkeyDown = true
        onHotkeyDown?(Date())
    }

    private func triggerHotkeyUp() {
        isHotkeyDown = false
        onHotkeyUp?(Date())
    }
}
