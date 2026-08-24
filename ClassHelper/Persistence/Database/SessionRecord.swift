//
//  SessionRecord.swift
//  ClassHelper
//

import Foundation
import GRDB

nonisolated struct SessionRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    static let databaseTableName = "sessions"

    let sessionID: String
    let lectureStartedAt: String
    let lectureTimezone: String
    let lectureLocalDate: String
    let lectureLocalYear: Int
    let lectureLocalMonth: Int
    let lectureLocalDay: Int
    let lectureLocalHour: Int
    let lectureLocalMinute: Int
    let recordingState: String
    let localProcessingState: String
    let publicationState: String
    let lastVerifiedStage: String?
    let canonicalPath: String?
    let title: String?
    let failureCategory: String?
    let failureCode: String?
    let discardRequested: Bool
    let attemptCount: Int?
    let lastAttemptedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case lectureStartedAt = "lecture_started_at"
        case lectureTimezone = "lecture_timezone"
        case lectureLocalDate = "lecture_local_date"
        case lectureLocalYear = "lecture_local_year"
        case lectureLocalMonth = "lecture_local_month"
        case lectureLocalDay = "lecture_local_day"
        case lectureLocalHour = "lecture_local_hour"
        case lectureLocalMinute = "lecture_local_minute"
        case recordingState = "recording_state"
        case localProcessingState = "local_processing_state"
        case publicationState = "publication_state"
        case lastVerifiedStage = "last_verified_stage"
        case canonicalPath = "canonical_path"
        case title
        case failureCategory = "failure_category"
        case failureCode = "failure_code"
        case discardRequested = "discard_requested"
        case attemptCount = "attempt_count"
        case lastAttemptedAt = "last_attempted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        lectureSession: LectureSession,
        recordingState: RecordingState,
        localProcessingState: LocalProcessingState,
        publicationState: PublicationState,
        lastVerifiedStage: String? = nil,
        canonicalPath: String? = nil,
        title: String? = nil,
        failureCategory: String? = nil,
        failureCode: String? = nil,
        discardRequested: Bool,
        attemptCount: Int? = nil,
        lastAttemptedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        sessionID = lectureSession.sessionID
        lectureStartedAt = Self.encode(lectureSession.lectureStartedAt)
        lectureTimezone = lectureSession.lectureTimezone
        lectureLocalDate = lectureSession.lectureLocalDate
        lectureLocalYear = lectureSession.lectureLocalYear
        lectureLocalMonth = lectureSession.lectureLocalMonth
        lectureLocalDay = lectureSession.lectureLocalDay
        lectureLocalHour = lectureSession.lectureLocalHour
        lectureLocalMinute = lectureSession.lectureLocalMinute
        self.recordingState = recordingState.rawValue
        self.localProcessingState = localProcessingState.rawValue
        self.publicationState = publicationState.rawValue
        self.lastVerifiedStage = lastVerifiedStage
        self.canonicalPath = canonicalPath
        self.title = title
        self.failureCategory = failureCategory
        self.failureCode = failureCode
        self.discardRequested = discardRequested
        self.attemptCount = attemptCount
        self.lastAttemptedAt = lastAttemptedAt.map(Self.encode)
        self.createdAt = Self.encode(createdAt)
        self.updatedAt = Self.encode(updatedAt)
    }

    func lectureSession() throws -> LectureSession {
        guard
            let sessionID = UUID(uuidString: sessionID),
            let startedAt = Self.decode(lectureStartedAt),
            let timeZone = TimeZone(identifier: lectureTimezone)
        else {
            throw PersistenceError.invalidPersistedSession
        }

        let session = LectureSession(
            sessionID: sessionID,
            lectureStartedAt: startedAt,
            lectureTimeZone: timeZone
        )
        guard
            session.lectureLocalDate == lectureLocalDate,
            session.lectureLocalYear == lectureLocalYear,
            session.lectureLocalMonth == lectureLocalMonth,
            session.lectureLocalDay == lectureLocalDay,
            session.lectureLocalHour == lectureLocalHour,
            session.lectureLocalMinute == lectureLocalMinute
        else {
            throw PersistenceError.invalidPersistedSession
        }
        return session
    }

    private static func encode(_ date: Date) -> String {
        formatter().string(from: date)
    }

    private static func decode(_ value: String) -> Date? {
        formatter().date(from: value)
    }

    private static func formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
