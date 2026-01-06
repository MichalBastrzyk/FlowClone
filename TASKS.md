# FlowClone — TASKS (execution order)

## 0) Repo hygiene (required)
- [ ] Initialize git repo and commit “init project”.
- [ ] Add .gitignore for Xcode.
- [ ] Add docs: SPEC.md, ARCHITECTURE.md, TASKS.md.

## 1) Xcode project baseline
- [ ] Create macOS SwiftUI App target (macOS 14+).
- [ ] Ensure app is signed with a Development Team.
- [ ] Add Info.plist key:
  - [ ] `NSMicrophoneUsageDescription` with a clear string. [ref: https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSMicrophoneUsageDescription]

## 2) Settings + configuration backbone
- [ ] Add Settings window (SwiftUI).
- [ ] Add `AppSettings` model (Observable) backed by UserDefaults.
- [ ] Implement KeychainService for Groq API key (set/get/delete).
- [ ] Add UI for API key management.

## 3) Permissions layer
- [ ] Implement `PermissionsService`:
  - [ ] Microphone permission request + status.
  - [ ] Accessibility/Input Monitoring guidance + prompt button. [ref: https://gertrude.app/blog/macos-request-accessibility-control] [ref: https://developer.apple.com/forums/thread/789896]
- [ ] Settings shows live permission status.

## 4) Audio capture
- [ ] Implement `AudioCaptureService.start()` -> RecordingSession (temp file).
- [ ] Implement `AudioCaptureService.stop()` -> final file URL ready to read.
- [ ] Add max duration enforcement (timer in Coordinator).

## 5) Groq transcription
- [ ] Implement `TranscriptionService.transcribe(fileURL, model, language)` via URLSession multipart:
  - [ ] Endpoint: `https://api.groq.com/openai/v1/audio/transcriptions` [ref: https://console.groq.com/docs/speech-to-text]
  - [ ] Parse JSON; return `.text`.
- [ ] Robust error mapping (401, offline, timeout).

## 6) Text injection
- [ ] Implement TextInjectionService:
  - [ ] Paste mode with clipboard restore.
  - [ ] Type mode with unicode-safe typing.
- [ ] Gate injection behind permission checks.

## 7) Hotkey service (press + release)
- [ ] Implement `HotkeyService` using `CGEvent.tapCreate` keyDown + keyUp.
- [ ] Attempt Fn/Globe detection; if fails:
  - [ ] Provide fallback hotkey picker UI and store config.
- [ ] Emit `hotkeyDown` and `hotkeyUp` callbacks only once per physical press/release.

## 8) Core state machine + coordinator
- [ ] Implement DictationStateMachine:
  - [ ] deterministic transitions + guard conditions
  - [ ] schedule debounce and max duration timers
- [ ] Implement DictationCoordinator:
  - [ ] wire hotkey -> state machine
  - [ ] start/stop audio
  - [ ] transcribe
  - [ ] inject text
  - [ ] drive HUD and menu icon state

## 9) UI polish (Intentional Minimalism)
- [ ] Menu bar icon reflects state (idle/recording/transcribing/error).
- [ ] HUD overlay:
  - [ ] Recording pill with timer.
  - [ ] Transcribing pill.
  - [ ] Error pill (auto-dismiss).

## 10) Launch at login
- [ ] Implement LaunchAtLoginService using `SMAppService`. [ref: https://developer.apple.com/documentation/servicemanagement/smappservice]
- [ ] Toggle in Settings, persists and works after reboot.

## 11) Hardening
- [ ] Cleanup temp files on success/failure (default ON).
- [ ] Ensure clipboard always restored in paste mode.
- [ ] Ensure state returns to idle after failures.
- [ ] Add logs + a “Copy diagnostics” action.

## 12) README + manual QA checklist
- [ ] Write README:
  - setup Groq API key
  - grant mic permission
  - grant accessibility/input monitoring
  - hotkey configuration & Fn fallback
- [ ] Run all acceptance tests from SPEC.
