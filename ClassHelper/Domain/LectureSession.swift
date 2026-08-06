//
//  LectureSession.swift
//  ClassHelper
//

import Foundation

nonisolated struct LectureSession: Equatable, Sendable {
    let sessionID: String
    let lectureStartedAt: Date
    let lectureTimezone: String
    let lectureLocalDate: String
    let lectureLocalYear: Int
    let lectureLocalMonth: Int
    let lectureLocalDay: Int
    let lectureLocalHour: Int
    let lectureLocalMinute: Int

    init(
        sessionID: UUID = UUID(),
        lectureStartedAt: Date = Date(),
        lectureTimeZone: TimeZone = .current
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = lectureTimeZone
        let year = calendar.component(.year, from: lectureStartedAt)
        let month = calendar.component(.month, from: lectureStartedAt)
        let day = calendar.component(.day, from: lectureStartedAt)

        self.sessionID = sessionID.uuidString.lowercased()
        self.lectureStartedAt = lectureStartedAt
        self.lectureTimezone = lectureTimeZone.identifier
        lectureLocalDate = String(format: "%04d-%02d-%02d", year, month, day)
        lectureLocalYear = year
        lectureLocalMonth = month
        lectureLocalDay = day
        lectureLocalHour = calendar.component(.hour, from: lectureStartedAt)
        lectureLocalMinute = calendar.component(.minute, from: lectureStartedAt)
    }
}
