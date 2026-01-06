# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Open project in Xcode
open FlowClone.xcodeproj

# Or build from command line (requires Xcode developer tools)
xcodebuild -scheme FlowClone -configuration Debug build
```

**Note**: The project requires macOS 14.0+ and Xcode 16.0+. You must select a Development Team in project settings before building.

## View Logs

```bash
log stream --predicate 'subsystem == "com.michalbastrzyk.FlowClone"' --level debug
```

## Architecture Overview

FlowClone is a **state machine-driven macOS menu bar app** with strict separation of concerns. The architecture follows three core principles:

1. **Single-source-of-truth state machine**: All app state flows through `DictationStateMachine`
2. **Service isolation**: Each capability (audio, transcription, injection, etc.) is a pure service
3. **Coordinator pattern**: `DictationCoordinator` wires everything together—no implicit globals

### State Machine (The Heart of the App)

The entire app lifecycle is defined by `DictationState` in `Models/DictationState.swift`:

```
idle → arming → recording → stopping → transcribing → injecting → idle
  ↓                                                         ↓
error (auto-recovery after 3s) ← ← ← ← ← ← ← ← ← ← ← ← ← ← ←
```

**Critical state transitions to understand:**

- `idle` → `arming` (65ms debounce to prevent accidental triggers)
- `arming` → `recording` (only if microphone permission granted)
- `recording` → `stopping` → `transcribing` (async chain)
- Any error → `idle` (automatic recovery after 3 seconds)

All state transitions are **deterministic**—see `DictationStateMachine.swift` handle() method. When adding new features, you typically:

1. Add new case to `DictationState` enum
2. Add corresponding `DictationEvent` case
3. Implement transition logic in `handle(_:)` method
4. Update UI to reflect new state

### Coordinator Pattern

`DictationCoordinator` is the **only** singleton in the app. It:

- Creates and owns all service instances
- Sets up hotkey callbacks
- Bridges services to the state machine
- Provides diagnostic utilities

**Do not create additional global state**. If you need new behavior:
- Create a service in `Services/`
- Inject it into `DictationCoordinator` via `setupStateMachine()`
- Use it from state machine transitions

### Service Layer Contracts

All services in `Services/` follow this pattern:

- **Shared instance**: `static let shared = ServiceName()`
- **No UI dependencies**: Services never reference SwiftUI/AppKit directly
- **Explicit side effects**: Async methods use `async throws`
- **Logging via `Logger.shared`**: Never log sensitive data (API keys, user content)

Key services and their responsibilities:

- `AudioCaptureService`: `AVAudioEngine` recording → temp file URL
- `TranscriptionService`: Groq API multipart upload → transcript string
- `TextInjectionService`: Two modes (paste/type) → CGEvent synthesis
- `HotkeyService`: `CGEvent.tapCreate` → callbacks for DOWN/UP
- `PermissionsService`: Checks macOS permissions (mic, accessibility, input monitoring)
- `KeychainService`: Secure storage for Groq API key

### UI Layer

- **MenuBarView**: Menu bar entry point, uses SwiftUI `MenuBarExtra`
- **SettingsView**: Tabbed interface (General, Permissions, About)
- **HUDView`: Floating overlay shown during recording/transcribing
- **HUDWindowController**: AppKit window wrapper for HUD

UI observes state via `@Observable` on `DictationStateMachine`. When state changes, UI updates automatically.

### Critical Implementation Details

**Hotkey Debouncing (Performance Target: ≤100ms):**
- State machine arms for 65ms before recording
- Prevents accidental triggers while maintaining responsiveness
- Implemented via Timer in `DictationStateMachine.transitionToArming()`

**Recording Session Management:**
- Each recording gets a UUID and temp file URL
- Temp files: `FileManager.default.temporaryDirectory/FlowClone/`
- Cleanup happens after successful injection (if "Delete temp audio" enabled)

**Two Text Injection Modes:**
1. **Paste mode** (default): Saves clipboard → Cmd+V → restores clipboard (faster, ~200ms)
2. **Type mode**: CGEvent per character (slower, more compatible)

**Permissions Handling:**
- Microphone: Requested via AVFoundation on first launch
- Accessibility/Input Monitoring: Cannot be auto-granted; user must enable in System Settings
- App shows warnings in menu bar if permissions missing

### Persistence Strategy

- **UserDefaults**: Settings (model, language, insertion mode, hotkey config)
  - See `AppSettings.swift` for full list
- **Keychain**: Groq API key (never store in UserDefaults)

### When Adding Features

**New Settings:**
1. Add property to `AppSettings` with UserDefaults backing
2. Add UI control in `SettingsView.swift` (appropriate tab)
3. Expose via `@Published` for UI reactivity

**New States:**
1. Add case to `DictationState` enum
2. Add corresponding `DictationEvent` cases
3. Implement transitions in `DictationStateMachine.handle()`
4. Update HUD/UI to display new state

**New Services:**
1. Create in `Services/` following existing patterns
2. Add to `DictationStateMachine` dependencies
3. Wire up in `DictationCoordinator.setupStateMachine()`

### Known Constraints

- **Sandbox limitations**: App sandbox may interfere with Accessibility/Input Monitoring. Users may need to disable sandbox for full functionality.
- **Fn/Globe key**: Detection varies by keyboard. Fallback hotkey (e.g., Cmd+Shift+Space) is provided.
- **Type mode**: Currently has simplified character mapping (English keyboard optimized). Full Unicode support requires UCKeyTranslate API integration.

### Testing Manual Acceptance

Before shipping changes, verify these scenarios from `SPEC.md`:

1. **Happy path**: Hold hotkey → speak "hello world" → release → text appears
2. **Permissions**: Deny microphone → app shows error, remains stable
3. **Clipboard restore**: Copy "CLIP" → dictate "TEST" → paste → clipboard still "CLIP"
4. **Fallback hotkey**: If Fn not detected, fallback hotkey works with press-and-hold

### File Organization (Quick Reference)

```
FlowClone/
├── Models/              # Data models only
├── Services/            # Pure services, no UI
├── Core/                # State machine + coordinator
├── Views/               # SwiftUI + AppKit UI
└── FlowCloneApp.swift   # App entry point
```

**Key principle**: If you're touching UI code from a service, you're probably violating the architecture. Use the coordinator pattern or state machine instead.
