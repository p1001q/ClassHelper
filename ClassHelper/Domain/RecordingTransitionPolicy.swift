//
//  RecordingTransitionPolicy.swift
//  ClassHelper
//

nonisolated enum RecordingTransitionPolicy {
    static func transition(
        from state: RecordingState,
        command: SessionCommand
    ) throws -> RecordingState {
        switch (state, command) {
        case (.ready, .start), (.blocked, .start):
            return .starting
        case (.starting, .startCommitted):
            return .recording
        case (.starting, .startFailed):
            return .ready
        case (.starting, .startBlocked):
            return .blocked
        case (.recording, .pause):
            return .paused
        case (.paused, .resume):
            return .recording
        case (.recording, .stop), (.paused, .stop):
            return .stopping
        case (.stopping, .stopCommitted):
            return .ready
        default:
            throw DomainError.invalidRecordingTransition(state: state, command: command)
        }
    }
}
