# FlowClone — SPEC (MVP)

## One-liner
A macOS menu bar app that records while a hotkey is held, transcribes via Groq Whisper, then injects the text into the currently focused input.

## Primary User Story
As a user, I place my cursor in any text field, press-and-hold the hotkey to speak, release to stop, and the spoken text appears where my cursor is.

## Core Behavior (MVP)
### Hold-to-record
- On Hotkey DOWN:
  - App enters `arming` (debounce 50–80ms).
  - If key is still down after debounce, start microphone recording immediately.
- While Hotkey held:
  - Continue recording.
  - Ignore key repeat / additional keyDown events.
- On Hotkey UP:
  - Stop recording immediately.
  - Close audio file (must be valid and readable).
  - Transition to `transcribing`.

### Transcription
- Upload the recorded audio file to Groq Speech-to-Text:
  - Endpoint: `https://api.groq.com/openai/v1/audio/transcriptions`
  - Default model: `whisper-large-v3-turbo`
- Parse JSON response and extract transcript text.
- Delete temp audio file after transcription attempt finishes (success or failure) unless user turned off “Delete temp audio”.

### Text insertion
Two insertion modes (user-selectable):
1) Paste mode (default):
  - Preserve clipboard contents.
  - Set clipboard to transcript.
  - Synthesize Cmd+V into the frontmost app.
  - Restore clipboard contents.
2) Type mode:
  - Synthesize keyboard events per character (supports Unicode, newlines).

### UI
- Menu bar app with:
  - Status indicator (idle/recording/transcribing/error).
  - “Open Settings…” item.
  - “Quit” item.
- Minimal HUD overlay (small pill) while:
  - Recording: shows “Recording” + timer (or subtle waveform).
  - Transcribing: shows “Transcribing…”.
  - Error: shows 1-line error message + disappears after a short delay.

## Permissions Requirements
### Microphone
- Must include `NSMicrophoneUsageDescription` in Info.plist and request capture permission at runtime (macOS requires explicit user permission). [ref: https://developer.apple.com/documentation/bundleresources/requesting-authorization-for-media-capture-on-macos] [ref: https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSMicrophoneUsageDescription]

### Global hotkey + injection
- The app requires user-granted privileges to observe global keyboard events and to synthesize input.
- Must show a clear, actionable Settings screen with:
  - Permission status indicators.
  - A button that triggers the system prompt / instructions to grant privileges (e.g., via AX trust prompt and/or Input Monitoring guidance for event taps). [ref: https://developer.apple.com/forums/thread/789896] [ref: https://gertrude.app/blog/macos-request-accessibility-control]

## Hotkey
- Default: attempt Fn/Globe “press-and-hold”.
- MUST provide a fallback: if Fn/Globe can’t be captured, user selects an alternative hotkey.
- Hotkey must support DOWN and UP events (not just “toggle”). Fn is known to be tricky in many systems, so fallback must be first-class. [ref: https://github.com/tauri-apps/global-hotkey/issues/111]

## Settings (MVP)
- Groq API key:
  - Set / Update / Remove
  - Stored in Keychain (not UserDefaults).
- Model selection:
  - Default: `whisper-large-v3-turbo`
  - Allow switching to a “more accurate” model if available.
- Language:
  - Auto (default)
  - Fixed language code (e.g., `en`, `pl`)
- Insertion mode:
  - Paste (default)
  - Type
- Delete temp audio:
  - On (default)
- Launch at login:
  - On/Off using `SMAppService`. [ref: https://developer.apple.com/documentation/servicemanagement/smappservice]
- Hotkey:
  - “Try Fn/Globe” + status
  - “Choose fallback hotkey…”

## Error Handling Rules
- If microphone permission denied:
  - Recording does not start.
  - HUD + Settings show actionable instructions.
- If required privileges for hotkey/injection denied:
  - Hotkey listening/injection is disabled.
  - Settings show actionable instructions.
- If Groq request fails (401/timeout/offline):
  - Show HUD error (non-blocking).
  - Return to idle.
  - Temp file cleanup still happens.

## Performance Targets (MVP)
- Key-down to recording start: <= 100ms perceived.
- Release to stop: immediate.
- Transcription: async; UI never blocks.
- Injection: < 200ms after transcript received for typical short dictations.

## Manual Acceptance Tests
1) Notes/TextEdit happy path:
   - Put cursor in editor.
   - Hold hotkey 2 seconds, speak “hello world”.
   - Release hotkey.
   - “hello world” appears at cursor.
2) Permission denial:
   - Deny Microphone: app shows “Mic required” and remains stable.
3) Clipboard restore:
   - Copy text “CLIP”.
   - Dictate “TEST”.
   - After paste injection, clipboard still equals “CLIP”.
4) Fn fallback:
   - If Fn not detected, selecting fallback hotkey works with press-and-hold.
