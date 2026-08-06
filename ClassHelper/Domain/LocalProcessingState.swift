//
//  LocalProcessingState.swift
//  ClassHelper
//

nonisolated enum LocalProcessingState: String, CaseIterable, Sendable {
    case capturing = "CAPTURING"
    case finalizingTranscript = "FINALIZING_TRANSCRIPT"
    case generatingNote = "GENERATING_NOTE"
    case savingLocal = "SAVING_LOCAL"
    case localComplete = "LOCAL_COMPLETE"
    case recoverableFailed = "RECOVERABLE_FAILED"
    case unrecoverableFailed = "UNRECOVERABLE_FAILED"
    case discarded = "DISCARDED"
}
