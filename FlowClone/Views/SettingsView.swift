//
//  SettingsView.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI
import Combine

struct SettingsView: View {
    private let barCount = AudioWaveformMonitor.barCount

    @State private var settings = AppSettings()
    @State private var permissions = PermissionsService.shared
    @State private var launchAtLogin = LaunchAtLoginService.shared
    @State private var keychain = KeychainService.shared

    @State private var apiKeyInput: String = ""
    @State private var showingAPIKeyError = false
    @State private var apiKeyErrorMessage = ""

    // Hotkey test playground state
    @State private var currentlyPressedModifiers: Set<String> = []
    @State private var selectedHotkeyModifiers: Set<ModifierOption> = []

    // Waveform test state
    @State private var magnitudes = [Float](repeating: 0, count: AudioWaveformMonitor.barCount)
    @State private var testMagnitude: Float = 0.0
    @State private var useRealAudio: Bool = false
    private let audioTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect() // ~60fps

    var currentMagnitudes: [Float] {
        useRealAudio ? magnitudes : Array(repeating: testMagnitude, count: barCount)
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            hotkeyTab
                .tabItem {
                    Label("Hotkey", systemImage: "command")
                }

            waveformTestTab
                .tabItem {
                    Label("Waveform", systemImage: "waveform")
                }

            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised.fill")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 550, height: 450)
        .onAppear {
            loadAPIKey()
            loadHotkeySettings()
            setupHotkeyMonitoring()
        }
        .onReceive(audioTimer) { _ in
            if useRealAudio {
                magnitudes = AudioWaveformMonitor.shared.magnitudes
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("API Key") {
                SecureField("Groq API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKeyInput.isEmpty)

                    if keychain.hasGroqAPIKey() {
                        Button("Remove") {
                            removeAPIKey()
                        }
                    }

                    Spacer()

                    if keychain.hasGroqAPIKey() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text("Get your API key from console.groq.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Transcription") {
                Picker("Model", selection: $settings.transcriptionModel) {
                    ForEach(TranscriptionModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                Picker("Language", selection: $settings.languageMode) {
                    ForEach(LanguageMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Text Injection") {
                Picker("Mode", selection: $settings.insertionMode) {
                    ForEach(InsertionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .help("Paste mode is faster, Type mode works in more apps")

                Toggle("Delete temp audio files", isOn: $settings.deleteTempAudio)
            }

            Section("Launch") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try launchAtLogin.enable()
                            } else {
                                try launchAtLogin.disable()
                            }
                        } catch {
                            Logger.shared.error("Failed to toggle launch at login: \(error.localizedDescription)")
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Hotkey Tab

    private var hotkeyTab: some View {
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

    // MARK: - Waveform Test Tab

    private var waveformTestTab: some View {
        Form {
            Section("Waveform Visualization") {
                VStack(spacing: 20) {
                    // Waveform preview - matches actual recording pill
                    HStack(spacing: 0) {
                        HStack(spacing: 3) {
                            ForEach(0..<barCount, id: \.self) { i in
                                let magnitude = i < currentMagnitudes.count ? currentMagnitudes[i] : 0
                                WaveBar(
                                    index: i,
                                    magnitude: magnitude,
                                    isRecording: true
                                )
                            }
                        }
                        .frame(height: 32, alignment: .center) // Center vertically
                        .padding(.leading, 20) // Left padding inside pill
                        .padding(.trailing, 20) // Right padding inside pill
                    }
                    .padding(.horizontal, 0) // No extra horizontal padding
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.black)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )

                    // Magnitude display
                    HStack {
                        Text("Average Magnitude:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let avgMagnitude = currentMagnitudes.reduce(0, +) / Float(currentMagnitudes.count)
                        Text(String(format: "%.3f", avgMagnitude))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }

            Section("Controls") {
                Toggle("Use Real Audio Input", isOn: $useRealAudio)
                    .help("When enabled, uses your actual microphone. When disabled, use the slider below.")
                    .onChange(of: useRealAudio) { _, isRealAudio in
                        if isRealAudio {
                            // Start monitoring
                            Task {
                                await AudioWaveformMonitor.shared.startMonitoring()
                            }
                        } else {
                            // Stop monitoring
                            AudioWaveformMonitor.shared.stopMonitoring()
                        }
                    }

                if !useRealAudio {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Manual Magnitude")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", testMagnitude))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $testMagnitude, in: 0...1)
                            .controlSize(.small)

                        HStack(spacing: 10) {
                            Button("0.0") { testMagnitude = 0.0 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("0.25") { testMagnitude = 0.25 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("0.5") { testMagnitude = 0.5 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("0.75") { testMagnitude = 0.75 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("1.0") { testMagnitude = 1.0 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Info") {
                Text("Uses FFT (Fast Fourier Transform) to analyze audio frequencies. Each bar represents a different frequency range.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            // Stop monitoring when leaving the tab
            if useRealAudio {
                useRealAudio = false
                AudioWaveformMonitor.shared.stopMonitoring()
            }
        }
    }

    // MARK: - Permissions Tab

    private var permissionsTab: some View {
        Form {
            Section("Required Permissions") {
                permissionRow(
                    title: "Microphone",
                    icon: "mic.fill",
                    status: permissions.microphonePermissionStatus,
                    action: {
                        Task {
                            do {
                                try await permissions.requestMicrophonePermission()
                            } catch {
                                Logger.shared.error("Failed to request microphone permission: \(error.localizedDescription)")
                            }
                        }
                    },
                    actionLabel: "Request"
                )

                permissionRow(
                    title: "Accessibility",
                    icon: "hand.raised.fill",
                    status: permissions.accessibilityPermissionStatus,
                    action: {
                        permissions.promptForAccessibilityPermission()
                    },
                    actionLabel: "Open Settings"
                )
            }

            Section("Info") {
                Text("FlowClone requires these permissions to function:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Microphone: To record audio")
                    Text("• Accessibility: For global hotkey and text injection")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            permissions.refreshAllPermissions()
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("FlowClone")
                .font(.title)
                .fontWeight(.bold)

            Text("Voice dictation directly where you need it")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Version:")
                        .foregroundColor(.secondary)
                    Text("1.0.0")
                }

                HStack {
                    Text("Made by:")
                        .foregroundColor(.secondary)
                    Text("Michał Bastrzyk")
                }
            }

            Spacer()

            Button("Copy Diagnostics") {
                DictationCoordinator.shared.copyDiagnostics()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Views

    private func permissionRow(
        title: String,
        icon: String,
        status: PermissionStatus,
        action: @escaping () -> Void,
        actionLabel: String
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(status == .granted ? .green : (status == .denied ? .red : .orange))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)

                Text(statusText(for: status))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if status != .granted {
                Button(actionLabel) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }

    private func statusText(for status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not requested"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied - Open System Settings to enable"
        }
    }

    // MARK: - API Key Management

    private func loadAPIKey() {
        if let key = try? keychain.getGroqAPIKey() {
            apiKeyInput = key
        }
    }

    private func saveAPIKey() {
        do {
            try keychain.setGroqAPIKey(apiKeyInput)
            Logger.shared.info("API key saved successfully")
        } catch {
            apiKeyErrorMessage = error.localizedDescription
            showingAPIKeyError = true
            Logger.shared.error("Failed to save API key: \(error.localizedDescription)")
        }
    }

    private func removeAPIKey() {
        do {
            try keychain.deleteGroqAPIKey()
            apiKeyInput = ""
            Logger.shared.info("API key removed")
        } catch {
            Logger.shared.error("Failed to remove API key: \(error.localizedDescription)")
        }
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

// MARK: - Supporting Types

enum ModifierOption: CaseIterable, Hashable {
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
}

extension ModifierOption: Comparable {
    static func < (lhs: ModifierOption, rhs: ModifierOption) -> Bool {
        lhs.displayName < rhs.displayName
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
