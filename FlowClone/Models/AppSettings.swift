//
//  AppSettings.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import Observation

@Observable
final class AppSettings {
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let insertionMode = "insertionMode"
        static let model = "transcriptionModel"
        static let languageMode = "languageMode"
        static let deleteTempAudio = "deleteTempAudio"
        static let launchAtLogin = "launchAtLogin"
        static let hotkeyFallbackKeyCode = "hotkeyFallbackKeyCode"
        static let hotkeyFallbackModifiers = "hotkeyFallbackModifiers"
        static let useFnGlobeHotkey = "useFnGlobeHotkey"
    }

    // MARK: - Settings
    var insertionMode: InsertionMode {
        didSet { UserDefaults.standard.set(insertionMode.rawValue, forKey: Keys.insertionMode) }
    }

    var transcriptionModel: TranscriptionModel {
        didSet { UserDefaults.standard.set(transcriptionModel.rawValue, forKey: Keys.model) }
    }

    var languageMode: LanguageMode {
        didSet { UserDefaults.standard.set(languageMode.rawValue, forKey: Keys.languageMode) }
    }

    var deleteTempAudio: Bool {
        didSet { UserDefaults.standard.set(deleteTempAudio, forKey: Keys.deleteTempAudio) }
    }

    var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    var useFnGlobeHotkey: Bool {
        didSet { UserDefaults.standard.set(useFnGlobeHotkey, forKey: Keys.useFnGlobeHotkey) }
    }

    var fallbackHotkey: HotkeyConfig? {
        didSet {
            if let config = fallbackHotkey {
                UserDefaults.standard.set(config.keyCode, forKey: Keys.hotkeyFallbackKeyCode)
                UserDefaults.standard.set(config.modifiers.rawValue, forKey: Keys.hotkeyFallbackModifiers)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.hotkeyFallbackKeyCode)
                UserDefaults.standard.removeObject(forKey: Keys.hotkeyFallbackModifiers)
            }
        }
    }

    // MARK: - Init
    init() {
        self.insertionMode = InsertionMode(rawValue: UserDefaults.standard.string(forKey: Keys.insertionMode) ?? InsertionMode.paste.rawValue) ?? .paste
        self.transcriptionModel = TranscriptionModel(rawValue: UserDefaults.standard.string(forKey: Keys.model) ?? TranscriptionModel.whisperLargeV3Turbo.rawValue) ?? .whisperLargeV3Turbo
        self.languageMode = LanguageMode(rawValue: UserDefaults.standard.string(forKey: Keys.languageMode) ?? LanguageMode.auto.rawValue) ?? .auto
        self.deleteTempAudio = UserDefaults.standard.object(forKey: Keys.deleteTempAudio) as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        self.useFnGlobeHotkey = UserDefaults.standard.object(forKey: Keys.useFnGlobeHotkey) as? Bool ?? true

        // Load fallback hotkey if saved
        if let keyCode = UserDefaults.standard.object(forKey: Keys.hotkeyFallbackKeyCode) as? Int,
           let modifiersRaw = UserDefaults.standard.object(forKey: Keys.hotkeyFallbackModifiers) as? UInt,
           let modifiers = NSEvent.ModifierFlags(rawValue: modifiersRaw) {
            self.fallbackHotkey = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        } else {
            self.fallbackHotkey = nil
        }
    }
}

// MARK: - Supporting Types

enum InsertionMode: String, CaseIterable {
    case paste = "Paste"
    case type = "Type"

    var displayName: String {
        rawValue
    }
}

enum TranscriptionModel: String, CaseIterable {
    case whisperLargeV3Turbo = "whisper-large-v3-turbo"
    case whisperLargeV3 = "whisper-large-v3"

    var displayName: String {
        switch self {
        case .whisperLargeV3Turbo: return "Fast (whisper-large-v3-turbo)"
        case .whisperLargeV3: return "Accurate (whisper-large-v3)"
        }
    }
}

enum LanguageMode: String, CaseIterable {
    case auto = "auto"
    case en = "en"
    case es = "es"
    case fr = "fr"
    case de = "de"
    case pl = "pl"
    case zh = "zh"
    case ja = "ja"

    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .en: return "English"
        case .es: return "Spanish"
        case .fr: return "French"
        case .de: return "German"
        case .pl: return "Polish"
        case .zh: return "Chinese"
        case .ja: return "Japanese"
        }
    }
}

struct HotkeyConfig: Equatable, Codable {
    let keyCode: Int
    let modifiers: NSEvent.ModifierFlags

    var displayName: String {
        let modifierString: String
        if modifiers.isEmpty {
            modifierString = ""
        } else {
            let parts: [String] = []
            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            modifierString = parts.joined()
        }
        return "\(modifierString) \(keyCode)"
    }
}
