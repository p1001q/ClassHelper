//
//  DomainError.swift
//  ClassHelper
//

nonisolated enum DomainError: Error, Equatable, Sendable {
    case invalidRecordingTransition(state: RecordingState, command: SessionCommand)
    case invalidLocalProcessingTransition(
        state: LocalProcessingState,
        command: LocalProcessingCommand
    )
}
