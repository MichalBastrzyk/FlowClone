//
//  AppSettings.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import AppKit
import Observation

@Observable
final class AppSettings {
    // MARK: - Singleton
    static let shared = AppSettings()

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let insertionMode = "insertionMode"
        static let model = "transcriptionModel"
        static let languageMode = "languageMode"
        static let deleteTempAudio = "deleteTempAudio"
        static let launchAtLogin = "launchAtLogin"
        static let hotkeyFallbackKeyCode = "hotkeyFallbackKeyCode"
        static let hotkeyFallbackModifiers = "hotkeyFallbackModifiers"
        static let hotkeyIsModifierOnly = "hotkeyIsModifierOnly"
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
                UserDefaults.standard.set(config.modifiersRawValue, forKey: Keys.hotkeyFallbackModifiers)
                UserDefaults.standard.set(config.isModifierOnly, forKey: Keys.hotkeyIsModifierOnly)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.hotkeyFallbackKeyCode)
                UserDefaults.standard.removeObject(forKey: Keys.hotkeyFallbackModifiers)
                UserDefaults.standard.removeObject(forKey: Keys.hotkeyIsModifierOnly)
            }
        }
    }

    // MARK: - Init
    private init() {
        self.insertionMode = InsertionMode(rawValue: UserDefaults.standard.string(forKey: Keys.insertionMode) ?? InsertionMode.paste.rawValue) ?? .paste
        self.transcriptionModel = TranscriptionModel(rawValue: UserDefaults.standard.string(forKey: Keys.model) ?? TranscriptionModel.whisperLargeV3Turbo.rawValue) ?? .whisperLargeV3Turbo
        self.languageMode = LanguageMode(rawValue: UserDefaults.standard.string(forKey: Keys.languageMode) ?? LanguageMode.auto.rawValue) ?? .auto
        self.deleteTempAudio = UserDefaults.standard.object(forKey: Keys.deleteTempAudio) as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        self.useFnGlobeHotkey = UserDefaults.standard.object(forKey: Keys.useFnGlobeHotkey) as? Bool ?? true

        // Load fallback hotkey if saved
        if let keyCode = UserDefaults.standard.object(forKey: Keys.hotkeyFallbackKeyCode) as? Int,
           let modifiersRaw = UserDefaults.standard.object(forKey: Keys.hotkeyFallbackModifiers) as? UInt,
           let isModifierOnly = UserDefaults.standard.object(forKey: Keys.hotkeyIsModifierOnly) as? Bool {
            if isModifierOnly {
                self.fallbackHotkey = HotkeyConfig(modifiers: NSEvent.ModifierFlags(rawValue: modifiersRaw))
            } else {
                self.fallbackHotkey = HotkeyConfig(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiersRaw))
            }
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

// HotkeyConfig is now in its own file: HotkeyConfig.swift
