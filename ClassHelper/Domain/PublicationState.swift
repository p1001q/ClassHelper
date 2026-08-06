//
//  PublicationState.swift
//  ClassHelper
//

nonisolated enum PublicationState: String, CaseIterable, Sendable {
    case notApplicable = "NOT_APPLICABLE"
    case queued = "QUEUED"
    case publishing = "PUBLISHING"
    case published = "PUBLISHED"
    case publishFailed = "PUBLISH_FAILED"
}
