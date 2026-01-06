# FlowClone — ARCHITECTURE

## Principles
- Single-source-of-truth state machine.
- Services are pure(ish) and side-effect boundaries are explicit.
- No implicit globals; everything wired through `DictationCoordinator`.

## High-level Components
### UI Layer (SwiftUI + minimal AppKit)
- Menu bar status + menu actions
- Settings window (SwiftUI)
- HUD overlay (borderless floating NSPanel/NSWindow)

### Core Layer
- `DictationStateMachine`: deterministic transitions + guards.
- `DictationCoordinator`: orchestrates services; converts events into state transitions.

### Services Layer
- `HotkeyService`: emits `hotkeyDown` / `hotkeyUp`.
- `PermissionsService`: checks + prompts permissions.
- `AudioCaptureService`: start/stop recording, returns temp file URL.
- `TranscriptionService`: file URL -> transcript string (Groq).
- `TextInjectionService`: transcript -> frontmost app (paste/type).
- `KeychainService`: store/retrieve Groq API key.
- `LaunchAtLoginService`: SMAppService register/unregister.

## State Machine
```swift
enum DictationState: Equatable {
  case idle
  case arming(startedAt: Date)
  case recording(session: RecordingSession)
  case stopping(session: RecordingSession)
  case transcribing(session: RecordingSession)
  case injecting(text: String)
  case error(message: String, recoverable: Bool)
}

struct RecordingSession: Equatable {
  let id: UUID
  let startedAt: Date
  let tempFileURL: URL
  let maxDurationSeconds: TimeInterval
}
```

### Events
```swift
enum DictationEvent {
  // hotkey
  case hotkeyDown(Date)
  case hotkeyUp(Date)

  // timers
  case armingDebounceFired
  case maxDurationReached

  // audio
  case recordingStarted(RecordingSession)
  case recordingStopped(RecordingSession)

  // transcription
  case transcriptionSucceeded(text: String)
  case transcriptionFailed(message: String)

  // injection
  case injectionSucceeded
  case injectionFailed(message: String)

  // permissions / configuration
  case permissionsChanged
}
```

### Transition Rules (must implement)
- `idle` + `hotkeyDown` -> `arming(startedAt:)` and schedule debounce (50–80ms).
- `arming` + `armingDebounceFired`:
  - If key still down AND permissions OK -> start recording -> `recording`.
  - Else -> `idle`.
- `recording` + `hotkeyUp` -> stop recording -> `stopping` -> then `transcribing`.
- `recording` + `maxDurationReached` -> stop recording -> `stopping`.
- `transcribing` ignores hotkeyDown/up (MVP), optionally show HUD “Busy”.
- On any failure -> `error` (recoverable) then auto-return to `idle` after N seconds.

## Hotkey capture strategy
- Primary: `CGEvent.tapCreate` (session event tap) in listen-only mode for down/up events.
- If Fn/Globe is not detectable:
  - Provide fallback hotkey selection and persist it.
- Note: event taps may require Input Monitoring and/or Accessibility privileges depending on configuration and OS behavior; treat “permission missing” as a first-class state and surface it in Settings. [ref: https://developer.apple.com/forums/thread/789896]

## Audio capture strategy
- Use `AVAudioEngine`:
  - Tap input node and write to `AVAudioFile`.
  - Ensure stop closes file and flushes buffers before uploading.
- Temp files:
  - Use `FileManager.default.temporaryDirectory/FlowClone/`.
  - Unique file per session UUID.

## Groq transcription strategy
- Multipart upload via URLSession.
- Endpoint: `/openai/v1/audio/transcriptions`
- Parse response JSON and extract `text`.
- Timeouts:
  - Use request timeout (e.g., 60s).
  - Fail gracefully with a user-visible error HUD.

## Text injection strategy
### Paste mode
- Save NSPasteboard items
- Set transcript
- Send Cmd+V via CGEvent
- Restore pasteboard

### Type mode
- Unicode-safe typing using CGEvent keyboard events.
- Must support:
  - Newlines -> Return key / "\n"
  - Tabs if present
  - Non-ASCII characters

## Persistence
- UserDefaults:
  - insertionMode
  - model
  - languageMode
  - deleteTempAudio
  - launchAtLogin
  - hotkey configuration
- Keychain:
  - Groq API Key

## Logging
- Central `Logger` with OSLog.
- Log state transitions, permission status changes, API responses (never log API keys).
