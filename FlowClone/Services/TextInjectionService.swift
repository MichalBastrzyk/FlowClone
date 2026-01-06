//
//  TextInjectionService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import Cocoa
import ApplicationServices

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

        // Small delay to ensure clipboard is set
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Synthesize Cmd+V
        await synthesizeKeyCode(9, withModifiers: .command) // VK_V = 9

        // Wait for paste to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Restore clipboard
        if let oldContents = oldContents {
            pasteboard.clearContents()
            pasteboard.setString(oldContents, forType: .string)
            Logger.shared.debug("Clipboard restored")
        }
    }

    // MARK: - Type Mode

    private func injectViaTyping(_ text: String) async throws {
        Logger.shared.debug("Injecting via typing...")

        // Get current keyboard layout
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)

        guard let layoutDataRaw = layoutData else {
            Logger.shared.error("Could not get keyboard layout")
            throw TextInjectionError.keyboardLayoutNotFound
        }

        let layoutData = unsafeBitCast(layoutDataRaw, to: CFData.self)
        let layoutPtr = CFDataGetBytePtr(layoutData)

        var lastChar: Character?
        var keyPressDelay: UInt64 = 10_000_000 // 10ms between keystrokes

        for char in text {
            // Handle newlines
            if char == "\n" {
                await synthesizeKeyCode(36, withModifiers: []) // VK_Return = 36
                try await Task.sleep(nanoseconds: keyPressDelay)
                lastChar = char
                continue
            }

            // Handle tabs
            if char == "\t" {
                await synthesizeKeyCode(48, withModifiers: []) // VK_Tab = 48
                try await Task.sleep(nanoseconds: keyPressDelay)
                lastChar = char
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
            await synthesizeKeyCode(keyCode, withModifiers: modifiers)
            try await Task.sleep(nanoseconds: keyPressDelay)

            lastChar = char
        }

        Logger.shared.debug("Typed \(text.count) characters")
    }

    // MARK: - Key Synthesis

    private func synthesizeKeyCode(_ keyCode: CGKeyCode, withModifiers: NSEvent.ModifierFlags) async {
        let flags = CGEventFlags(mask: (modifiersToCGFlags(withModifiers)))

        // Key down
        if let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            eventDown.flags = flags
            eventDown.post(tap: .cgAnnotatedSessionEventTap)
        }

        // Small delay
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms

        // Key up
        if let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            eventUp.flags = flags
            eventUp.post(tap: .cgAnnotatedSessionEventTap)
        }
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
        let charCode = char.asciiValue ?? 0

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
