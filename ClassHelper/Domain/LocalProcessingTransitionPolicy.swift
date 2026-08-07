//
//  LocalProcessingTransitionPolicy.swift
//  ClassHelper
//

nonisolated enum LocalProcessingTransitionPolicy {
    static func transition(
        from state: LocalProcessingState,
        command: LocalProcessingCommand
    ) throws -> LocalProcessingState {
        switch (state, command) {
        case (.capturing, .captureEndedSafely):
            return .finalizingTranscript
        case (.finalizingTranscript, .finalizedTranscriptVerified):
            return .generatingNote
        case (.generatingNote, .generatedNoteVerified):
            return .savingLocal
        case (.savingLocal, .canonicalNoteReadBackVerified):
            return .localComplete
        case (
            .capturing,
            .recoverableFailureVerified
        ), (
            .finalizingTranscript,
            .recoverableFailureVerified
        ), (
            .generatingNote,
            .recoverableFailureVerified
        ), (
            .savingLocal,
            .recoverableFailureVerified
        ):
            return .recoverableFailed
        case (
            .capturing,
            .unrecoverableFailureCleanupCompletedAndVerified
        ), (
            .finalizingTranscript,
            .unrecoverableFailureCleanupCompletedAndVerified
        ), (
            .generatingNote,
            .unrecoverableFailureCleanupCompletedAndVerified
        ), (
            .savingLocal,
            .unrecoverableFailureCleanupCompletedAndVerified
        ):
            return .unrecoverableFailed
        case (.recoverableFailed, .retryFromUsableAudio):
            return .finalizingTranscript
        case (.recoverableFailed, .retryFromVerifiedTranscript):
            return .generatingNote
        case (.recoverableFailed, .retryFromValidGeneratedNote):
            return .savingLocal
        case (.recoverableFailed, .reconcileVerifiedFinalNote):
            return .localComplete
        case (.recoverableFailed, .confirmedDiscardCompletedAndVerified):
            return .discarded
        default:
            throw DomainError.invalidLocalProcessingTransition(state: state, command: command)
        }
    }
}
