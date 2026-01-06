//
//  RecordingSession.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation

struct RecordingSession: Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    let tempFileURL: URL
    let maxDurationSeconds: TimeInterval

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        tempFileURL: URL,
        maxDurationSeconds: TimeInterval = 300 // 5 minutes default
    ) {
        self.id = id
        self.startedAt = startedAt
        self.tempFileURL = tempFileURL
        self.maxDurationSeconds = maxDurationSeconds
    }
}
