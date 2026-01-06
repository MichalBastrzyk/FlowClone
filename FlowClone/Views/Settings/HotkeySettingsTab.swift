//
//  HotkeySettingsTab.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI
import AppKit

struct HotkeySettingsTab: View {
    private var settings: AppSettings { AppSettings.shared }

    @State private var currentlyPressedModifiers: Set<String> = []
    @State private var selectedHotkeyModifiers: Set<ModifierOption> = []

    var body: some View {
        Form {
            Section("Test Playground") {
                VStack(spacing: 12) {
                    Text("Press any modifier key to test detection:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        modifierKeyBadge("Fn", isPressed: currentlyPressedModifiers.contains("Fn"))
                        modifierKeyBadge("Shift", isPressed: currentlyPressedModifiers.contains("Shift"))
                        modifierKeyBadge("Control", isPressed: currentlyPressedModifiers.contains("Control"))
                        modifierKeyBadge("Option", isPressed: currentlyPressedModifiers.contains("Option"))
                        modifierKeyBadge("Command", isPressed: currentlyPressedModifiers.contains("Command"))
                    }
                    .padding(.vertical, 8)

                    Text("Selected: \(currentlyPressedModifiers.sorted().joined(separator: " + "))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(currentlyPressedModifiers.isEmpty ? .secondary : .primary)
                }
                .frame(maxWidth: .infinity)
            }

            Section("Hotkey Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select the modifier(s) to use as your recording hotkey:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Single Modifier", selection: $selectedHotkeyModifiers) {
                        Text("None").tag(Set<ModifierOption>())
                        Text("Fn").tag(Set<ModifierOption>([.fn]))
                        Text("Option ⌥").tag(Set<ModifierOption>([.option]))
                        Text("Control ⌃").tag(Set<ModifierOption>([.control]))
                        Text("Shift ⇧").tag(Set<ModifierOption>([.shift]))
                        Text("Command ⌘").tag(Set<ModifierOption>([.command]))
                    }
                    .onChange(of: selectedHotkeyModifiers) { _, _ in
                        saveHotkeySettings()
                    }

                    Divider()

                    Text("Combinations (hold all modifiers)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $selectedHotkeyModifiers) {
                        Text("None").tag(Set<ModifierOption>())
                        Text("Command + Option").tag(Set<ModifierOption>([.command, .option]))
                        Text("Command + Shift").tag(Set<ModifierOption>([.command, .shift]))
                        Text("Control + Option").tag(Set<ModifierOption>([.control, .option]))
                    }
                    .onChange(of: selectedHotkeyModifiers) { _, _ in
                        saveHotkeySettings()
                    }
                }

                HStack {
                    Text("Current hotkey:")
                        .foregroundColor(.secondary)
                    Text(hotkeyDisplayString)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.vertical, 4)

                Text("Hold your selected modifier(s) to start recording, release to stop")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadHotkeySettings()
            setupHotkeyMonitoring()
        }
    }

    private func modifierKeyBadge(_ name: String, isPressed: Bool) -> some View {
        Text(name)
            .font(.system(.caption, design: .rounded))
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed ? Color.accentColor : Color.gray.opacity(0.2))
            )
            .foregroundColor(isPressed ? .white : .primary)
    }

    private var hotkeyDisplayString: String {
        if selectedHotkeyModifiers.isEmpty {
            return "Not set"
        }

        let sorted = selectedHotkeyModifiers.sorted { $0.displayName < $1.displayName }
        return sorted.map { $0.displayName }.joined(separator: " + ")
    }

    // MARK: - Hotkey Management

    private func loadHotkeySettings() {
        guard let config = settings.fallbackHotkey, config.isModifierOnly else {
            selectedHotkeyModifiers = []
            return
        }

        var modifiers: Set<ModifierOption> = []

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

        // Fn is detected by having no standard modifiers
        if modifiers.isEmpty && config.isModifierOnly {
            modifiers.insert(.fn)
        }

        selectedHotkeyModifiers = modifiers
    }

    private func saveHotkeySettings() {
        if selectedHotkeyModifiers.isEmpty {
            settings.fallbackHotkey = nil
            HotkeyService.shared.setFallbackHotkey(nil)
            return
        }

        var flags: NSEvent.ModifierFlags = []

        for modifier in selectedHotkeyModifiers {
            switch modifier {
            case .shift:
                flags.insert(.shift)
            case .control:
                flags.insert(.control)
            case .option:
                flags.insert(.option)
            case .command:
                flags.insert(.command)
            case .fn:
                // Fn is handled separately
                break
            }
        }

        let config = HotkeyConfig(modifiers: flags)
        settings.fallbackHotkey = config
        HotkeyService.shared.setFallbackHotkey(config)

        Logger.shared.info("Hotkey saved: \(hotkeyDisplayString)")
    }

    private func setupHotkeyMonitoring() {
        // Listen to modifier changes for the test playground
        HotkeyService.shared.onModifiersChanged = { modifiers in
            DispatchQueue.main.async {
                self.currentlyPressedModifiers = Set(modifiers.map { $0.displayName })
            }
        }
    }
}

#Preview {
    HotkeySettingsTab()
        .frame(width: 550, height: 450)
}
