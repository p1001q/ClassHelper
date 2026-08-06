//
//  LectureSessionIdentityTests.swift
//  ClassHelperTests
//

import Foundation
import Testing
@testable import ClassHelper

struct LectureSessionIdentityTests {
    private let fixedUUID = UUID(uuidString: "A1B2C3D4-E5F6-4789-ABCD-0123456789AB")!
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    @Test("고정 UUID를 lowercase canonical session ID로 캡처한다")
    func capturesLowercaseCanonicalSessionID() {
        let session = LectureSession(
            sessionID: fixedUUID,
            lectureStartedAt: Date(timeIntervalSince1970: 0),
            lectureTimeZone: seoul
        )

        #expect(session.sessionID == "a1b2c3d4-e5f6-4789-abcd-0123456789ab")
    }

    @Test("production 기본 ID는 RFC 4122 UUID v4이다")
    func productionSessionIDIsUUIDVersion4() throws {
        let session = LectureSession()
        let uuid = try #require(UUID(uuidString: session.sessionID))
        let bytes = uuid.uuid

        #expect((bytes.6 >> 4) == 4)
        #expect((bytes.8 & 0b1100_0000) == 0b1000_0000)
    }

    @Test("고정 시작 시각과 IANA timezone에서 local identity를 계산한다")
    func capturesLocalIdentityAtStart() {
        let startedAt = Date(timeIntervalSince1970: 1_786_032_930) // 2026-08-06 16:15:30 UTC

        let session = LectureSession(
            sessionID: fixedUUID,
            lectureStartedAt: startedAt,
            lectureTimeZone: seoul
        )

        #expect(session.lectureStartedAt == startedAt)
        #expect(session.lectureTimezone == "Asia/Seoul")
        #expect(session.lectureLocalDate == "2026-08-07")
        #expect(session.lectureLocalYear == 2026)
        #expect(session.lectureLocalMonth == 8)
        #expect(session.lectureLocalDay == 7)
        #expect(session.lectureLocalHour == 1)
        #expect(session.lectureLocalMinute == 15)
    }

    @Test("UTC 날짜와 다른 시작 당시 local 날짜를 보존한다")
    func capturesLocalDateAcrossUTCBoundary() {
        let startedAt = Date(timeIntervalSince1970: 1_785_947_400) // 2026-08-05 16:30:00 UTC

        let session = LectureSession(
            sessionID: fixedUUID,
            lectureStartedAt: startedAt,
            lectureTimeZone: seoul
        )

        #expect(session.lectureLocalDate == "2026-08-06")
        #expect(session.lectureLocalHour == 1)
        #expect(session.lectureLocalMinute == 30)
    }

    @Test("이후 시각이 자정을 지나도 시작 identity와 local 시간이 변하지 않는다")
    func remainsStableAfterMidnight() {
        let startedAt = Date(timeIntervalSince1970: 1_786_027_140) // 2026-08-06 14:39:00 UTC
        let session = LectureSession(
            sessionID: fixedUUID,
            lectureStartedAt: startedAt,
            lectureTimeZone: seoul
        )
        let capturedSession = session

        _ = LectureSession(
            sessionID: UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!,
            lectureStartedAt: startedAt.addingTimeInterval(3_600),
            lectureTimeZone: seoul
        )

        #expect(session == capturedSession)
        #expect(session.lectureLocalDate == "2026-08-06")
        #expect(session.lectureLocalHour == 23)
        #expect(session.lectureLocalMinute == 39)
    }

    @Test("주입 timezone이 이후 바뀌어도 캡처한 timezone과 local identity가 변하지 않는다")
    func remainsStableAfterTimeZoneChanges() {
        let startedAt = Date(timeIntervalSince1970: 1_785_947_400)
        var currentTimeZone = seoul
        let session = LectureSession(
            sessionID: fixedUUID,
            lectureStartedAt: startedAt,
            lectureTimeZone: currentTimeZone
        )

        currentTimeZone = TimeZone(identifier: "America/Los_Angeles")!

        #expect(currentTimeZone.identifier == "America/Los_Angeles")
        #expect(session.lectureTimezone == "Asia/Seoul")
        #expect(session.lectureLocalDate == "2026-08-06")
        #expect(session.lectureLocalHour == 1)
        #expect(session.lectureLocalMinute == 30)
    }

    @Test("같은 session value를 후속 단계로 전달하면 identity와 시작 시간이 동일하다")
    func preservesIdentityAcrossDownstreamProcessing() {
        let session = LectureSession(
            sessionID: fixedUUID,
            lectureStartedAt: Date(timeIntervalSince1970: 1_785_947_400),
            lectureTimeZone: seoul
        )

        let processed = passToNextStage(session)

        #expect(processed == session)
        #expect(processed.sessionID == session.sessionID)
        #expect(processed.lectureStartedAt == session.lectureStartedAt)
        #expect(processed.lectureTimezone == session.lectureTimezone)
        #expect(processed.lectureLocalDate == session.lectureLocalDate)
    }

    @Test("Lecture Session identity/time value는 Sendable 경계를 만족한다")
    func isSendable() async {
        let session = LectureSession(
            sessionID: fixedUUID,
            lectureStartedAt: Date(timeIntervalSince1970: 1_785_947_400),
            lectureTimeZone: seoul
        )

        let transferred = await Task.detached { session }.value

        #expect(transferred == session)
    }

    private func passToNextStage(_ session: LectureSession) -> LectureSession {
        session
    }
}
