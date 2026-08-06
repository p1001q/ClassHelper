//
//  RecordingTransitionPolicyTests.swift
//  ClassHelperTests
//

import Testing
@testable import ClassHelper

struct RecordingTransitionPolicyTests {
    @Test("세 상태 축은 모든 Canonical 상태를 표현한다")
    func stateAxesRepresentCanonicalStates() {
        #expect(Set(RecordingState.allCases.map(\.rawValue)) == [
            "READY", "RECORDING", "PAUSED", "STARTING", "STOPPING", "BLOCKED",
        ])
        #expect(Set(LocalProcessingState.allCases.map(\.rawValue)) == [
            "CAPTURING", "FINALIZING_TRANSCRIPT", "GENERATING_NOTE", "SAVING_LOCAL",
            "LOCAL_COMPLETE", "RECOVERABLE_FAILED", "UNRECOVERABLE_FAILED", "DISCARDED",
        ])
        #expect(Set(PublicationState.allCases.map(\.rawValue)) == [
            "NOT_APPLICABLE", "QUEUED", "PUBLISHING", "PUBLISHED", "PUBLISH_FAILED",
        ])
    }

    @Test(
        "합법적인 recording control 전이를 허용한다",
        arguments: [
            (RecordingState.ready, SessionCommand.start, RecordingState.starting),
            (.blocked, .start, .starting),
            (.starting, .startCommitted, .recording),
            (.starting, .startFailed, .ready),
            (.starting, .startBlocked, .blocked),
            (.recording, .pause, .paused),
            (.paused, .resume, .recording),
            (.recording, .stop, .stopping),
            (.paused, .stop, .stopping),
            (.stopping, .stopCommitted, .ready),
        ]
    )
    func allowsLegalTransition(
        from state: RecordingState,
        command: SessionCommand,
        to expectedState: RecordingState
    ) throws {
        #expect(try RecordingTransitionPolicy.transition(from: state, command: command) == expectedState)
    }

    @Test(
        "commit 중 중복 control을 typed error로 거부한다",
        arguments: [
            (RecordingState.starting, SessionCommand.start),
            (.starting, .pause),
            (.starting, .resume),
            (.starting, .stop),
            (.stopping, .start),
            (.stopping, .pause),
            (.stopping, .resume),
            (.stopping, .stop),
        ]
    )
    func rejectsDuplicateControlDuringCommit(
        state: RecordingState,
        command: SessionCommand
    ) {
        #expect(throws: DomainError.invalidRecordingTransition(state: state, command: command)) {
            try RecordingTransitionPolicy.transition(from: state, command: command)
        }
    }

    @Test("현재 상태에서 허용되지 않은 command를 거부하고 기존 값을 보존한다")
    func rejectsInvalidCommandWithoutChangingExistingState() {
        let currentState = RecordingState.ready

        #expect(throws: DomainError.invalidRecordingTransition(state: .ready, command: .pause)) {
            try RecordingTransitionPolicy.transition(from: currentState, command: .pause)
        }
        #expect(currentState == .ready)
    }

    @Test("정의되지 않은 모든 state와 command 조합을 typed error로 거부한다")
    func rejectsEveryUndefinedTransition() {
        for state in RecordingState.allCases {
            for command in SessionCommand.allCases where expectedState(from: state, command: command) == nil {
                #expect(throws: DomainError.invalidRecordingTransition(state: state, command: command)) {
                    try RecordingTransitionPolicy.transition(from: state, command: command)
                }
            }
        }
    }

    private func expectedState(
        from state: RecordingState,
        command: SessionCommand
    ) -> RecordingState? {
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
            return nil
        }
    }
}
