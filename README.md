# FlowClone

A macOS menu bar app that records while a hotkey is held, transcribes via Groq Whisper, then injects the text into the currently focused input.

## Features

- **Hold-to-Record**: Hold your hotkey to record, release to transcribe
- **Fast Transcription**: Powered by Groq's Whisper API
- **Multiple Injection Modes**: Paste mode (faster) or Type mode (more compatible)
- **Menu Bar App**: Lives in your menu bar, out of the way
- **Privacy First**: Audio files are deleted by default after transcription
- **Launch at Login**: Optional auto-start on system boot

## Requirements

- macOS 14.0+
- Xcode 16.0+ (for building)
- Groq API key (get one free at [console.groq.com](https://console.groq.com))

## Building

1. Open `FlowClone.xcodeproj` in Xcode
2. Select your development team in the Signing & Capabilities tab
3. Build and run (⌘R)

## First Time Setup

### 1. Grant Microphone Permission

When you first launch FlowClone, you'll be prompted to grant microphone access. This is required for recording audio.

### 2. Set Your Groq API Key

1. Click the FlowClone menu bar icon
2. Select "Settings..."
3. Go to the "General" tab
4. Enter your Groq API key and click "Save API Key"

Get your API key at [console.groq.com](https://console.groq.com/keys).

### 3. Grant Accessibility/Input Monitoring Permissions

FlowClone needs special permissions to:
- Use global hotkeys
- Inject text into other applications

Open the "Permissions" tab in Settings and click "Open Settings" for:
- **Accessibility** (preferred, enables both hotkey and text injection)
- **Input Monitoring** (alternative, enables only hotkey)

### 4. Configure Your Hotkey

By default, FlowClone attempts to use the Fn/Globe key. If that doesn't work on your system, you can set a fallback hotkey in Settings.

## Usage

### Basic Dictation

1. Place your cursor in any text field
2. Hold your hotkey (Fn/Globe or your configured fallback)
3. Speak clearly
4. Release the hotkey
5. Your transcribed text will appear!

### Settings Options

**Transcription Settings:**
- **Model**: Choose between Fast (whisper-large-v3-turbo) or Accurate (whisper-large-v3)
- **Language**: Auto-detect or specify a language

**Text Injection:**
- **Paste Mode** (default): Uses clipboard paste - faster but requires clipboard access
- **Type Mode**: Simulates keystrokes - slower but works in more apps

**Other:**
- **Delete temp audio**: Automatically delete recordings after transcription
- **Launch at login**: Start FlowClone automatically on system boot

## Project Structure

```
FlowClone/
├── Models/                  # Data models
│   ├── AppSettings.swift
│   ├── DictationState.swift
│   └── RecordingSession.swift
├── Services/                # Service layer
│   ├── AudioCaptureService.swift
│   ├── HotkeyService.swift
│   ├── KeychainService.swift
│   ├── LaunchAtLoginService.swift
│   ├── Logger.swift
│   ├── PermissionsService.swift
│   ├── TextInjectionService.swift
│   └── TranscriptionService.swift
├── Core/                    # State machine and coordinator
│   ├── DictationCoordinator.swift
│   └── DictationStateMachine.swift
├── Views/                   # UI components
│   ├── HUDView.swift
│   ├── HUDWindow.swift
│   ├── MenuBarView.swift
│   └── SettingsView.swift
└── FlowCloneApp.swift       # App entry point
```

## Architecture

FlowClone uses a state machine architecture with a coordinator pattern:

- **DictationStateMachine**: Manages state transitions (idle → arming → recording → transcribing → injecting)
- **DictationCoordinator**: Orchestrates all services and handles hotkey events
- **Services**: Isolated components for each concern (audio, transcription, injection, etc.)

### State Machine

```
idle → arming → recording → stopping → transcribing → injecting → idle
  ↓                                                         ↓
error (auto-recovery) ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ←
```

## Troubleshooting

### Hotkey Not Working

If your Fn/Globe key doesn't trigger recording:
1. Go to Settings → General
2. Set a fallback hotkey (e.g., Cmd+Shift+Space)

### Text Not Appearing

If transcription succeeds but text doesn't appear:
1. Try switching to "Type" mode in Settings
2. Make sure you've granted Accessibility permission
3. Check that the target app is focused

### Transcription Errors

If you get transcription errors:
1. Verify your Groq API key is valid in Settings
2. Check your internet connection
3. Try the "Accurate" model for better results

### Permission Issues

If the app shows permission warnings:
1. Open System Settings > Privacy & Security
2. Grant the required permissions
3. Restart FlowClone

## Development

### Adding New Features

1. **New Settings**: Add to `AppSettings.swift` and update `SettingsView.swift`
2. **New States**: Add to `DictationState.swift` and update transitions in `DictationStateMachine.swift`
3. **New Services**: Create in `Services/` and inject into `DictationCoordinator`

### Logging

FlowClone uses the unified logging system. View logs in Console.app:

```bash
log stream --predicate 'subsystem == "com.michalbastrzyk.FlowClone"' --level debug
```

### Diagnostics

To copy diagnostic information:
1. Click the FlowClone menu bar icon
2. Select "Settings..."
3. Go to the "About" tab
4. Click "Copy Diagnostics"

## License

MIT License - Feel free to use and modify as needed.

## Credits

- Built with SwiftUI and AppKit
- Transcription powered by [Groq](https://groq.com)
- Uses OpenAI's Whisper model via Groq API
