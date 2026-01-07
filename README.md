# FlowClone

**Free, open-source alternative to WhisperFlow.**

A minimalist macOS dictation app that transcribes your voice to text—anywhere, anytime. Just hold a key, speak, and your words appear.

## Why FlowClone?

- **100% Free & Open Source** — No subscriptions, no hidden costs
- **Bring Your Own Keys** — Use your own Groq API key (free tier available!)
- **Privacy-First** — Audio deleted by default, nothing stored on our servers
- **Lightning Fast** — Powered by Groq's Whisper API (~1-2s transcription)
- **Works Everywhere** — Dictate into any app: Slack, VS Code, Notes, you name it

---

## Quick Start

### Prerequisites

- macOS 14.0+
- A free [Groq API key](https://console.groq.com/keys) (sign up, it's free!)

### Installation

```bash
git clone https://github.com/michalbstrzyk/FlowClone.git
cd FlowClone
open FlowClone.xcodeproj
```

1. Select your **Development Team** in Xcode signing settings
2. Build & run (⌘R)

### First Run

1. **Grant Microphone Access** when prompted
2. **Paste your Groq API key** in Settings → General
3. **Enable Accessibility** in Settings → Permissions (required for hotkeys & text injection)

That's it! You're ready to dictate.

---

## How It Works

1. Place cursor in any text field
2. Hold **Fn/Globe** (or your custom hotkey)
3. Speak
4. Release
5. Text appears automatically ✨

---

## Features

| Feature | Description |
|---------|-------------|
| **Hold-to-Record** | Hold key to record, release to transcribe |
| **Smart Injection** | Paste mode (fast) or Type mode (compatible) |
| **Visual Feedback** | Real-time waveform visualization while recording |
| **Auto-Delete** | Temp audio files removed after transcription |
| **Launch at Login** | Start automatically with your Mac |
| **Multiple Languages** | Auto-detect or pick from 50+ languages |

---

## Configuration

### Hotkey

Default: **Fn/Globe** key (hold to record)

Fallback: Set a custom combo in Settings (e.g., ⌘⇧Space)

### Text Injection

**Paste Mode** (default)
- Faster (~200ms)
- Simulates ⌘V
- Requires clipboard access

**Type Mode**
- Slower but more compatible
- Simulates keystrokes
- Works in clipboard-restricted apps

### Transcription

Choose speed vs accuracy:
- **Fast** (whisper-large-v3-turbo) — ~1s
- **Accurate** (whisper-large-v3) — ~2s

---

## Troubleshooting

**Hotkey not working?**
→ Set a fallback key in Settings → General

**Text not appearing?**
→ Switch to "Type" mode in Settings → General

**Transcription failed?**
→ Check your API key in Settings → General

**Permission errors?**
→ Grant Accessibility in System Settings → Privacy & Security

---

## Architecture

FlowClone is built with a state machine architecture:

- **DictationStateMachine** — Single source of truth for app state
- **Service Layer** — Isolated components (audio, transcription, injection)
- **Coordinator Pattern** — Clean separation of concerns

```
idle → arming → recording → stopping → transcribing → injecting → idle
```

---

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

### Development Setup

```bash
# View logs
log stream --predicate 'subsystem == "com.michalbastrzyk.FlowClone"' --level debug
```

See [CLAUDE.md](CLAUDE.md) for architecture documentation.

---

## License

[MIT](LICENSE) — Free to use, modify, and distribute.

---

## Acknowledgments

- Built with **SwiftUI** and **AppKit**
- Transcription powered by [Groq](https://groq.com)
- Uses OpenAI's **Whisper** model via Groq API
- Inspired by [WhisperFlow](https://whisperflow.app)
- Waveform visualization inspired by [Create with Swift](https://www.createwithswift.com/creating-a-live-audio-waveform-in-swiftui/)
