//
//  HotkeyConfig.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import AppKit

/// Configuration for a hotkey (modifier-based or key+modifier combo)
struct HotkeyConfig: Equatable, Codable {
    let keyCode: Int
    let modifiersRawValue: UInt
    let isModifierOnly: Bool

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    // Regular hotkey with key code + modifiers
    init(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiers.rawValue
        self.isModifierOnly = false
    }

    // Modifier-only hotkey (e.g., hold Fn, hold Right Option)
    init(modifiers: NSEvent.ModifierFlags) {
        self.keyCode = 0 // Not used for modifier-only
        self.modifiersRawValue = modifiers.rawValue
        self.isModifierOnly = true
    }

    var displayName: String {
        if isModifierOnly {
            var parts: [String] = []
            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            return parts.isEmpty ? "Fn" : parts.joined(separator: "+")
        } else {
            var parts: [String] = []
            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            let modifierString = parts.joined()
            return "\(modifierString) Key\(keyCode)"
        }
    }

    /// Convert to a set of ModifierOption for easier comparison
    func toModifierSet() -> Set<ModifierOption> {
        var result: Set<ModifierOption> = []

        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.control) { result.insert(.control) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.command) { result.insert(.command) }

        // If no standard modifiers and is modifier-only, assume Fn
        if result.isEmpty && isModifierOnly {
            result.insert(.fn)
        }

        return result
    }

    /// Create from a set of ModifierOption
    static func from(modifiers: Set<ModifierOption>) -> HotkeyConfig? {
        guard !modifiers.isEmpty else { return nil }

        var flags: NSEvent.ModifierFlags = []

        for modifier in modifiers {
            switch modifier {
            case .shift: flags.insert(.shift)
            case .control: flags.insert(.control)
            case .option: flags.insert(.option)
            case .command: flags.insert(.command)
            case .fn: break // Fn handled by having no standard modifiers
            }
        }

        return HotkeyConfig(modifiers: flags)
    }
}
