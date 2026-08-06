//
//  RecordingState.swift
//  ClassHelper
//

nonisolated enum RecordingState: String, CaseIterable, Sendable {
    case ready = "READY"
    case recording = "RECORDING"
    case paused = "PAUSED"
    case starting = "STARTING"
    case stopping = "STOPPING"
    case blocked = "BLOCKED"
}
