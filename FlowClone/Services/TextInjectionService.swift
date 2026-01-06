//
//  TextInjectionService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import Cocoa
import ApplicationServices
import Carbon

final class TextInjectionService {
    static let shared = TextInjectionService()

    private init() {}

    // MARK: - Injection

    func inject(_ text: String, mode: InsertionMode) async throws {
        Logger.shared.info("Injecting text using \(mode.displayName) mode...")

        guard !text.isEmpty else {
            Logger.shared.info("No text to inject")
            return
        }

        // Check if there's a frontmost application to receive text
        let runningApps = NSWorkspace.shared.runningApplications
        guard let frontmostApp = runningApps.first(where: { $0.isActive }),
              let bundleId = frontmostApp.bundleIdentifier else {
            Logger.shared.error("No active application found to inject text")
            throw TextInjectionError.frontmostAppNotAvailable
        }

        Logger.shared.debug("Frontmost app: \(bundleId)")

        switch mode {
        case .paste:
            try await injectViaPaste(text)
        case .type:
            try await injectViaTyping(text)
        }

        Logger.shared.info("Text injection successful")
    }

    // MARK: - Paste Mode

    private func injectViaPaste(_ text: String) async throws {
        Logger.shared.debug("Injecting via paste...")

        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)

        // Set new clipboard content
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Logger.shared.debug("Clipboard set with \(text.count) characters")

        // Delay to ensure clipboard is set
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms (increased from 50ms)

        // Synthesize Cmd+V
        Logger.shared.debug("Sending Cmd+V...")
        try await synthesizeKeyCode(9, withModifiers: .command) // VK_V = 9

        // Wait longer for paste to complete (some apps need more time)
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms (increased from 200ms)

        // Restore clipboard
        if let oldContents = oldContents {
            pasteboard.clearContents()
            pasteboard.setString(oldContents, forType: .string)
            Logger.shared.debug("Clipboard restored to: \(oldContents.prefix(50))...")
        }
    }

    // MARK: - Type Mode

    private func injectViaTyping(_ text: String) async throws {
        Logger.shared.debug("Injecting via typing...")

        // Get current keyboard layout
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let layoutProperty = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)

        guard let layoutDataRaw = layoutProperty else {
            Logger.shared.error("Could not get keyboard layout")
            throw TextInjectionError.keyboardLayoutNotFound
        }

        let layoutData = unsafeBitCast(layoutDataRaw, to: CFData.self)
        guard let layoutPtr = CFDataGetBytePtr(layoutData) else {
            Logger.shared.error("Could not get layout data pointer")
            throw TextInjectionError.keyboardLayoutNotFound
        }

        let keyPressDelay: UInt64 = 10_000_000 // 10ms between keystrokes

        for char in text {
            // Handle newlines
            if char == "\n" {
                try await synthesizeKeyCode(36, withModifiers: []) // VK_Return = 36
                try await Task.sleep(nanoseconds: keyPressDelay)
                continue
            }

            // Handle tabs
            if char == "\t" {
                try await synthesizeKeyCode(48, withModifiers: []) // VK_Tab = 48
                try await Task.sleep(nanoseconds: keyPressDelay)
                continue
            }

            // Convert character to key code
            let keyCode = charToKeyCode(char, layoutPtr: layoutPtr)

            // Handle modifiers for uppercase/symbols
            var modifiers: NSEvent.ModifierFlags = []

            if char.isUppercase || char.isSymbol || char.isPunctuation {
                modifiers = .shift
            }

            // Press and release key
            try await synthesizeKeyCode(keyCode, withModifiers: modifiers)
            try await Task.sleep(nanoseconds: keyPressDelay)
        }

        Logger.shared.debug("Typed \(text.count) characters")
    }

    // MARK: - Key Synthesis

    private func synthesizeKeyCode(_ keyCode: CGKeyCode, withModifiers: NSEvent.ModifierFlags) async throws {
        let flags = modifiersToCGFlags(withModifiers)

        // Key down
        guard let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            Logger.shared.error("Failed to create key down event for keyCode: \(keyCode)")
            throw TextInjectionError.injectionFailed
        }

        eventDown.flags = flags
        eventDown.post(tap: .cgAnnotatedSessionEventTap)
        Logger.shared.debug("Sent key down: keyCode=\(keyCode), flags=\(flags)")

        // Small delay between down and up
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms

        // Key up
        guard let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            Logger.shared.error("Failed to create key up event for keyCode: \(keyCode)")
            throw TextInjectionError.injectionFailed
        }

        eventUp.flags = flags
        eventUp.post(tap: .cgAnnotatedSessionEventTap)
        Logger.shared.debug("Sent key up: keyCode=\(keyCode), flags=\(flags)")
    }

    private func modifiersToCGFlags(_ modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []

        if modifiers.contains(.command) {
            flags.insert(.maskCommand)
        }
        if modifiers.contains(.option) {
            flags.insert(.maskAlternate)
        }
        if modifiers.contains(.control) {
            flags.insert(.maskControl)
        }
        if modifiers.contains(.shift) {
            flags.insert(.maskShift)
        }

        return flags
    }

    // MARK: - Character to Key Code

    private func charToKeyCode(_ char: Character, layoutPtr: UnsafePointer<UInt8>) -> CGKeyCode {
        // Map common characters to key codes
        // This is a simplified mapping - in production you'd use the UCKeyTranslate API
        let keyMap: [Character: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
            "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35,
            "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
            "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
            " ": 49, ".": 47, ",": 43, "/": 44, ";": 41, "'": 39,
            "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42, "`": 50
        ]

        let lowerChar = Character(char.lowercased())
        return keyMap[lowerChar] ?? 0 // Default to 'a' key
    }
}

enum TextInjectionError: LocalizedError {
    case keyboardLayoutNotFound
    case injectionFailed
    case frontmostAppNotAvailable

    var errorDescription: String? {
        switch self {
        case .keyboardLayoutNotFound:
            return "Could not determine keyboard layout"
        case .injectionFailed:
            return "Failed to inject text"
        case .frontmostAppNotAvailable:
            return "No active application found"
        }
    }
}
