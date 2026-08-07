//
//  LocalProcessingCommand.swift
//  ClassHelper
//

nonisolated enum LocalProcessingCommand: CaseIterable, Sendable {
    case captureEndedSafely
    case finalizedTranscriptVerified
    case generatedNoteVerified
    case canonicalNoteReadBackVerified
    case recoverableFailureVerified
    case unrecoverableFailureCleanupCompletedAndVerified
    case retryFromUsableAudio
    case retryFromVerifiedTranscript
    case retryFromValidGeneratedNote
    case reconcileVerifiedFinalNote
    case confirmedDiscardCompletedAndVerified
}
