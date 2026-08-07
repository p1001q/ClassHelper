//
//  LocalProcessingTransitionPolicyTests.swift
//  ClassHelperTests
//

import Testing
@testable import ClassHelper

struct LocalProcessingTransitionPolicyTests {
    private static let legalTransitions: [(
        LocalProcessingState,
        LocalProcessingCommand,
        LocalProcessingState
    )] = [
        (.capturing, .captureEndedSafely, .finalizingTranscript),
        (.finalizingTranscript, .finalizedTranscriptVerified, .generatingNote),
        (.generatingNote, .generatedNoteVerified, .savingLocal),
        (.savingLocal, .canonicalNoteReadBackVerified, .localComplete),
        (.capturing, .recoverableFailureVerified, .recoverableFailed),
        (.finalizingTranscript, .recoverableFailureVerified, .recoverableFailed),
        (.generatingNote, .recoverableFailureVerified, .recoverableFailed),
        (.savingLocal, .recoverableFailureVerified, .recoverableFailed),
        (.capturing, .unrecoverableFailureCleanupCompletedAndVerified, .unrecoverableFailed),
        (.finalizingTranscript, .unrecoverableFailureCleanupCompletedAndVerified, .unrecoverableFailed),
        (.generatingNote, .unrecoverableFailureCleanupCompletedAndVerified, .unrecoverableFailed),
        (.savingLocal, .unrecoverableFailureCleanupCompletedAndVerified, .unrecoverableFailed),
        (.recoverableFailed, .retryFromUsableAudio, .finalizingTranscript),
        (.recoverableFailed, .retryFromVerifiedTranscript, .generatingNote),
        (.recoverableFailed, .retryFromValidGeneratedNote, .savingLocal),
        (.recoverableFailed, .reconcileVerifiedFinalNote, .localComplete),
        (.recoverableFailed, .confirmedDiscardCompletedAndVerified, .discarded),
    ]

    @Test("Canonical 성공 pipeline 전체를 순서대로 전이한다")
    func completesCanonicalSuccessPipeline() throws {
        var state = LocalProcessingState.capturing
        let commands: [LocalProcessingCommand] = [
            .captureEndedSafely,
            .finalizedTranscriptVerified,
            .generatedNoteVerified,
            .canonicalNoteReadBackVerified,
        ]

        for command in commands {
            state = try LocalProcessingTransitionPolicy.transition(from: state, command: command)
        }

        #expect(state == .localComplete)
    }

    @Test("정의된 모든 합법 전이를 허용", arguments: legalTransitions)
    func allowsEveryLegalTransition(
        from state: LocalProcessingState,
        command: LocalProcessingCommand,
        to expectedState: LocalProcessingState
    ) throws {
        #expect(try LocalProcessingTransitionPolicy.transition(from: state, command: command) == expectedState)
    }

    @Test("retry가 다시 실패해도 verified recovery material이 있으면 recoverable 상태를 유지")
    func retryFailureRemainsRecoverable() throws {
        let retryState = try LocalProcessingTransitionPolicy.transition(
            from: .recoverableFailed,
            command: .retryFromUsableAudio
        )
        let failedState = try LocalProcessingTransitionPolicy.transition(
            from: retryState,
            command: .recoverableFailureVerified
        )

        #expect(failedState == .recoverableFailed)
    }

    @Test("unrecoverable terminal 전이는 외부 cleanup 완료와 부재 검증 결과만 수락")
    func unrecoverableTransitionRequiresVerifiedCleanupResult() throws {
        let state = try LocalProcessingTransitionPolicy.transition(
            from: .savingLocal,
            command: .unrecoverableFailureCleanupCompletedAndVerified
        )

        #expect(state == .unrecoverableFailed)
    }

    @Test("retry API에는 attempt count 입력이 없고 verified artifact command만 사용한다")
    func retryUsesVerifiedArtifactClassificationInsteadOfAttemptCount() throws {
        for _ in 0..<100 {
            let retryState = try LocalProcessingTransitionPolicy.transition(
                from: .recoverableFailed,
                command: .retryFromVerifiedTranscript
            )
            #expect(retryState == .generatingNote)
            #expect(
                try LocalProcessingTransitionPolicy.transition(
                    from: retryState,
                    command: .recoverableFailureVerified
                ) == .recoverableFailed
            )
        }
    }

    @Test("terminal state에서 모든 command를 거부")
    func rejectsEveryCommandFromTerminalStates() {
        let terminalStates: [LocalProcessingState] = [
            .localComplete, .unrecoverableFailed, .discarded,
        ]

        for state in terminalStates {
            for command in LocalProcessingCommand.allCases {
                #expect(
                    throws: DomainError.invalidLocalProcessingTransition(
                        state: state,
                        command: command
                    )
                ) {
                    try LocalProcessingTransitionPolicy.transition(from: state, command: command)
                }
            }
        }
    }

    @Test("단계 건너뛰기와 active state의 직접 Discard를 거부")
    func rejectsStageSkippingAndPrematureDiscard() {
        let invalidTransitions: [(LocalProcessingState, LocalProcessingCommand)] = [
            (.capturing, .finalizedTranscriptVerified),
            (.finalizingTranscript, .generatedNoteVerified),
            (.generatingNote, .canonicalNoteReadBackVerified),
            (.capturing, .confirmedDiscardCompletedAndVerified),
            (.finalizingTranscript, .confirmedDiscardCompletedAndVerified),
            (.generatingNote, .confirmedDiscardCompletedAndVerified),
            (.savingLocal, .confirmedDiscardCompletedAndVerified),
        ]

        for (state, command) in invalidTransitions {
            #expect(
                throws: DomainError.invalidLocalProcessingTransition(
                    state: state,
                    command: command
                )
            ) {
                try LocalProcessingTransitionPolicy.transition(from: state, command: command)
            }
        }
    }

    @Test("정의되지 않은 모든 state-command 조합을 typed error로 거부")
    func rejectsEveryUndefinedTransition() {
        let legalPairs = Set(Self.legalTransitions.map { TransitionPair(state: $0.0, command: $0.1) })

        for state in LocalProcessingState.allCases {
            for command in LocalProcessingCommand.allCases
            where !legalPairs.contains(TransitionPair(state: state, command: command)) {
                #expect(
                    throws: DomainError.invalidLocalProcessingTransition(
                        state: state,
                        command: command
                    )
                ) {
                    try LocalProcessingTransitionPolicy.transition(from: state, command: command)
                }
            }
        }
    }

    @Test("불법 전이는 기존 state value를 보존하고 error에 state와 command를 포함")
    func invalidTransitionPreservesStateAndIncludesContext() {
        var state = LocalProcessingState.generatingNote
        let command = LocalProcessingCommand.reconcileVerifiedFinalNote

        #expect(
            throws: DomainError.invalidLocalProcessingTransition(
                state: .generatingNote,
                command: .reconcileVerifiedFinalNote
            )
        ) {
            state = try LocalProcessingTransitionPolicy.transition(from: state, command: command)
        }
        #expect(state == .generatingNote)
    }

    @Test("local processing command/state/error는 Sendable 경계를 만족")
    func valuesAreSendable() async {
        let state = LocalProcessingState.recoverableFailed
        let command = LocalProcessingCommand.retryFromValidGeneratedNote
        let error = DomainError.invalidLocalProcessingTransition(state: state, command: command)

        let transferred = await Task.detached { (state, command, error) }.value

        #expect(transferred.0 == state)
        #expect(transferred.1 == command)
        #expect(transferred.2 == error)
    }

    private struct TransitionPair: Hashable {
        let state: LocalProcessingState
        let command: LocalProcessingCommand
    }
}
