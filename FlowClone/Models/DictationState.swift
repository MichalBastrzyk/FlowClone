//
//  DictationState.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation

enum DictationState: Equatable {
    case idle
    case arming(startedAt: Date)
    case recording(session: RecordingSession)
    case stopping(session: RecordingSession)
    case transcribing(session: RecordingSession)
    case injecting(text: String)
    case error(message: String, recoverable: Bool)

    static func == (lhs: DictationState, rhs: DictationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.arming(let l), .arming(let r)):
            return l == r
        case (.recording(let l), .recording(let r)):
            return l == r
        case (.stopping(let l), .stopping(let r)):
            return l == r
        case (.transcribing(let l), .transcribing(let r)):
            return l == r
        case (.injecting(let l), .injecting(let r)):
            return l == r
        case (.error(let lm, let lr), .error(let rm, let rr)):
            return lm == rm && lr == rr
        default:
            return false
        }
    }
}

enum DictationEvent {
    // Hotkey events
    case hotkeyDown(Date)
    case hotkeyUp(Date)

    // Timer events
    case armingDebounceFired
    case maxDurationReached

    // Audio events
    case recordingStarted(RecordingSession)
    case recordingStopped(RecordingSession)

    // Transcription events
    case transcriptionSucceeded(text: String)
    case transcriptionFailed(message: String)

    // Injection events
    case injectionSucceeded
    case injectionFailed(message: String)

    // Permissions / configuration
    case permissionsChanged
}
