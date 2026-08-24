//
//  SessionRepositoryTests.swift
//  ClassHelperTests
//

import Foundation
import GRDB
import Testing
@testable import ClassHelper

@Suite("Session repository", .serialized)
struct SessionRepositoryTests {
    private let session = LectureSession(
        sessionID: UUID(uuidString: "A1B2C3D4-E5F6-4789-ABCD-0123456789AB")!,
        lectureStartedAt: Date(timeIntervalSince1970: 1_785_947_400),
        lectureTimeZone: TimeZone(identifier: "Asia/Seoul")!
    )
    private let createdAt = Date(timeIntervalSince1970: 1_786_100_000.125)

    @Test("insert와 full lookup은 Lecture Session identity/time과 모든 상태 축을 round-trip 한다")
    func insertAndFullLookupRoundTrip() async throws {
        let context = try makeContext(times: [createdAt])

        let inserted = try await context.repository.insert(
            lectureSession: session,
            recordingState: .recording,
            localProcessingState: .capturing,
            publicationState: .notApplicable
        )
        let fetched = try await context.repository.session(sessionID: session.sessionID)

        #expect(inserted == fetched)
        #expect(fetched.lectureSession == session)
        #expect(fetched.recordingState == .recording)
        #expect(fetched.localProcessingState == .capturing)
        #expect(fetched.publicationState == .notApplicable)
        #expect(fetched.lastVerifiedStage == nil)
        #expect(fetched.canonicalPath == nil)
        #expect(fetched.title == nil)
        #expect(fetched.failureCategory == nil)
        #expect(fetched.failureCode == nil)
        #expect(!fetched.discardRequested)
        #expect(fetched.attemptCount == nil)
        #expect(fetched.lastAttemptedAt == nil)
        #expect(fetched.createdAt == createdAt)
        #expect(fetched.updatedAt == createdAt)
        #expect(try rowCount(in: context.database) == 1)
    }

    @Test("sub-millisecond lecture/time metadata를 exact round-trip 한다")
    func subMillisecondTimestampsRoundTripExactly() async throws {
        let preciseStartedAt = Date(timeIntervalSince1970: 1_785_947_400.123456)
        let preciseCreatedAt = Date(timeIntervalSince1970: 1_786_100_000.654321)
        let preciseSession = LectureSession(
            sessionID: UUID(uuidString: "B1C2D3E4-F5A6-4789-BCDE-1234567890AB")!,
            lectureStartedAt: preciseStartedAt,
            lectureTimeZone: TimeZone(identifier: "Asia/Seoul")!
        )
        let context = try makeContext(times: [preciseCreatedAt])

        _ = try await context.repository.insert(lectureSession: preciseSession)
        let fetched = try await context.repository.session(sessionID: preciseSession.sessionID)

        #expect(fetched.lectureSession == preciseSession)
        #expect(fetched.lectureSession.lectureStartedAt == preciseStartedAt)
        #expect(fetched.createdAt == preciseCreatedAt)
        #expect(fetched.updatedAt == preciseCreatedAt)
    }

    @Test("존재하지 않는 session lookup은 typed not-found를 반환한다")
    func missingSessionIsTypedNotFound() async throws {
        let context = try makeContext(times: [createdAt])

        do {
            _ = try await context.repository.session(sessionID: session.sessionID)
            Issue.record("존재하지 않는 session lookup이 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .sessionNotFound)
        } catch {
            Issue.record("typed not-found 대신 다른 error가 반환됐습니다")
        }
    }

    @Test("duplicate session identity는 거부하고 기존 full row를 보존한다")
    func duplicateIdentityPreservesExistingRow() async throws {
        let later = createdAt.addingTimeInterval(10)
        let context = try makeContext(times: [createdAt, later])
        let original = try await context.repository.insert(
            lectureSession: session,
            recordingState: .recording
        )

        do {
            _ = try await context.repository.insert(
                lectureSession: session,
                recordingState: .paused
            )
            Issue.record("duplicate session identity insert가 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .duplicateSessionIdentity)
        } catch {
            Issue.record("duplicate identity가 typed error로 mapping되지 않았습니다")
        }

        #expect(try await context.repository.session(sessionID: session.sessionID) == original)
        #expect(try rowCount(in: context.database) == 1)
    }

    @Test("recording legal transition은 해당 축과 updated_at만 변경한다")
    func recordingTransitionPreservesIdentityAndOtherAxes() async throws {
        let updatedAt = createdAt.addingTimeInterval(5)
        let context = try makeContext(times: [createdAt, updatedAt])
        let before = try await context.repository.insert(lectureSession: session)

        let after = try await context.repository.applyRecordingCommand(
            sessionID: session.sessionID,
            command: .start
        )

        #expect(after.recordingState == .starting)
        #expect(after.localProcessingState == before.localProcessingState)
        #expect(after.publicationState == before.publicationState)
        #expect(after.lectureSession == before.lectureSession)
        #expect(after.createdAt == before.createdAt)
        #expect(after.updatedAt == updatedAt)
        assertMetadataUnchanged(from: before, to: after)
    }

    @Test("local-processing legal transition은 해당 축과 updated_at만 변경한다")
    func localTransitionPreservesIdentityAndOtherAxes() async throws {
        let updatedAt = createdAt.addingTimeInterval(5)
        let context = try makeContext(times: [createdAt, updatedAt])
        let before = try await context.repository.insert(
            lectureSession: session,
            recordingState: .recording,
            localProcessingState: .capturing
        )

        let after = try await context.repository.applyLocalProcessingCommand(
            sessionID: session.sessionID,
            command: .captureEndedSafely
        )

        #expect(after.localProcessingState == .finalizingTranscript)
        #expect(after.recordingState == before.recordingState)
        #expect(after.publicationState == before.publicationState)
        #expect(after.lectureSession == before.lectureSession)
        #expect(after.createdAt == before.createdAt)
        #expect(after.updatedAt == updatedAt)
        assertMetadataUnchanged(from: before, to: after)
    }

    @Test("여러 단계 recording transition을 순차적으로 영속화한다")
    func persistsSequentialRecordingTransitions() async throws {
        let timestamps = (0...6).map { createdAt.addingTimeInterval(TimeInterval($0)) }
        let context = try makeContext(times: timestamps)
        _ = try await context.repository.insert(lectureSession: session)
        let commands: [SessionCommand] = [
            .start, .startCommitted, .pause, .resume, .stop, .stopCommitted,
        ]
        let expected: [RecordingState] = [
            .starting, .recording, .paused, .recording, .stopping, .ready,
        ]

        for (index, command) in commands.enumerated() {
            let result = try await context.repository.applyRecordingCommand(
                sessionID: session.sessionID,
                command: command
            )
            #expect(result.recordingState == expected[index])
            #expect(result.updatedAt == timestamps[index + 1])
        }

        let persisted = try await context.repository.session(sessionID: session.sessionID)
        #expect(persisted.recordingState == .ready)
        #expect(persisted.createdAt == createdAt)
    }

    @Test("여러 단계 local-processing success pipeline을 순차적으로 영속화한다")
    func persistsSequentialLocalProcessingTransitions() async throws {
        let timestamps = (0...4).map { createdAt.addingTimeInterval(TimeInterval($0)) }
        let context = try makeContext(times: timestamps)
        _ = try await context.repository.insert(lectureSession: session)
        let commands: [LocalProcessingCommand] = [
            .captureEndedSafely,
            .finalizedTranscriptVerified,
            .generatedNoteVerified,
            .canonicalNoteReadBackVerified,
        ]
        let expected: [LocalProcessingState] = [
            .finalizingTranscript, .generatingNote, .savingLocal, .localComplete,
        ]

        for (index, command) in commands.enumerated() {
            let result = try await context.repository.applyLocalProcessingCommand(
                sessionID: session.sessionID,
                command: command
            )
            #expect(result.localProcessingState == expected[index])
            #expect(result.updatedAt == timestamps[index + 1])
        }

        let persisted = try await context.repository.session(sessionID: session.sessionID)
        #expect(persisted.localProcessingState == .localComplete)
        #expect(persisted.createdAt == createdAt)
    }

    @Test("verified recovery classification과 artifact 기반 retry를 같은 session에 영속화한다")
    func persistsVerifiedFailureAndRetryTransitions() async throws {
        let timestamps = (0...7).map { createdAt.addingTimeInterval(TimeInterval($0)) }
        let context = try makeContext(times: timestamps)
        _ = try await context.repository.insert(lectureSession: session)
        let commands: [LocalProcessingCommand] = [
            .recoverableFailureVerified,
            .retryFromUsableAudio,
            .recoverableFailureVerified,
            .retryFromVerifiedTranscript,
            .recoverableFailureVerified,
            .retryFromValidGeneratedNote,
            .canonicalNoteReadBackVerified,
        ]
        let expected: [LocalProcessingState] = [
            .recoverableFailed,
            .finalizingTranscript,
            .recoverableFailed,
            .generatingNote,
            .recoverableFailed,
            .savingLocal,
            .localComplete,
        ]

        for (index, command) in commands.enumerated() {
            let result = try await context.repository.applyLocalProcessingCommand(
                sessionID: session.sessionID,
                command: command
            )
            #expect(result.localProcessingState == expected[index])
            #expect(result.lectureSession == session)
            #expect(result.attemptCount == nil)
            #expect(result.updatedAt == timestamps[index + 1])
        }
    }

    @Test("illegal recording command는 full row와 updated_at을 보존한다")
    func illegalRecordingCommandPreservesFullRow() async throws {
        let context = try makeContext(times: [createdAt])
        let before = try await context.repository.insert(lectureSession: session)

        do {
            _ = try await context.repository.applyRecordingCommand(
                sessionID: session.sessionID,
                command: .pause
            )
            Issue.record("illegal recording command가 성공하면 안 됩니다")
        } catch let error as DomainError {
            #expect(error == .invalidRecordingTransition(state: .ready, command: .pause))
        } catch {
            Issue.record("DomainError가 그대로 전달되지 않았습니다")
        }

        #expect(try await context.repository.session(sessionID: session.sessionID) == before)
    }

    @Test("illegal local command와 terminal state command는 full row를 보존한다")
    func illegalAndTerminalLocalCommandsPreserveFullRow() async throws {
        let context = try makeContext(times: [createdAt])
        let before = try await context.repository.insert(
            lectureSession: session,
            localProcessingState: .localComplete
        )

        do {
            _ = try await context.repository.applyLocalProcessingCommand(
                sessionID: session.sessionID,
                command: .captureEndedSafely
            )
            Issue.record("terminal local-processing state 변경이 성공하면 안 됩니다")
        } catch let error as DomainError {
            #expect(
                error == .invalidLocalProcessingTransition(
                    state: .localComplete,
                    command: .captureEndedSafely
                )
            )
        } catch {
            Issue.record("terminal state rejection이 DomainError가 아닙니다")
        }

        #expect(try await context.repository.session(sessionID: session.sessionID) == before)
    }

    @Test("corrupt persisted recording raw value는 typed fail-closed 결과이고 row를 수정하지 않는다")
    func corruptRecordingStateFailsClosed() async throws {
        let context = try makeContext(times: [createdAt])
        _ = try await context.repository.insert(lectureSession: session)
        try corrupt(
            column: "recording_state",
            value: "CORRUPT_RECORDING",
            sessionID: session.sessionID,
            database: context.database
        )
        let before = try rawRecord(in: context.database, sessionID: session.sessionID)

        do {
            _ = try await context.repository.applyRecordingCommand(
                sessionID: session.sessionID,
                command: .start
            )
            Issue.record("corrupt recording state에서 command가 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .invalidPersistedRecordingState)
        } catch {
            Issue.record("corrupt recording state가 typed persistence error가 아닙니다")
        }

        #expect(try rawRecord(in: context.database, sessionID: session.sessionID) == before)
    }

    @Test("corrupt persisted local-processing raw value는 typed fail-closed 결과이고 row를 수정하지 않는다")
    func corruptLocalProcessingStateFailsClosed() async throws {
        let context = try makeContext(times: [createdAt])
        _ = try await context.repository.insert(lectureSession: session)
        try corrupt(
            column: "local_processing_state",
            value: "CORRUPT_LOCAL",
            sessionID: session.sessionID,
            database: context.database
        )
        let before = try rawRecord(in: context.database, sessionID: session.sessionID)

        do {
            _ = try await context.repository.applyLocalProcessingCommand(
                sessionID: session.sessionID,
                command: .captureEndedSafely
            )
            Issue.record("corrupt local-processing state에서 command가 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .invalidPersistedLocalProcessingState)
        } catch {
            Issue.record("corrupt local-processing state가 typed persistence error가 아닙니다")
        }

        #expect(try rawRecord(in: context.database, sessionID: session.sessionID) == before)
    }

    @Test("서로 다른 repository actor의 동시 duplicate command 중 최대 하나만 성공한다")
    func concurrentDuplicateCommandHasAtMostOneSuccess() async throws {
        let context = try makeContext(times: [createdAt, createdAt.addingTimeInterval(1)])
        _ = try await context.repository.insert(
            lectureSession: session,
            recordingState: .recording
        )
        let otherTimestamp = createdAt.addingTimeInterval(2)
        let otherRepository = SessionRepository(
            database: context.database,
            now: { otherTimestamp }
        )

        async let first = recordingOutcome(
            repository: context.repository,
            sessionID: session.sessionID,
            command: .pause
        )
        async let second = recordingOutcome(
            repository: otherRepository,
            sessionID: session.sessionID,
            command: .pause
        )
        let outcomes = await [first, second]

        #expect(outcomes.filter { $0 == .success }.count == 1)
        #expect(outcomes.filter { $0 == .invalidTransition }.count == 1)
        #expect(
            try await context.repository.session(sessionID: session.sessionID).recordingState == .paused
        )
        #expect(try rowCount(in: context.database) == 1)
    }

    @Test("conditional update affected-row 0은 conflict로 fail closed한다")
    func zeroAffectedRowsIsConditionalConflict() async throws {
        let context = try makeContext(times: [createdAt, createdAt.addingTimeInterval(1)])
        let before = try await context.repository.insert(
            lectureSession: session,
            recordingState: .recording
        )
        try await context.database.pool.write { db in
            try db.execute(
                sql: """
                    CREATE TRIGGER ignore_recording_update
                    BEFORE UPDATE OF recording_state ON sessions
                    BEGIN
                        SELECT RAISE(IGNORE);
                    END
                    """
            )
        }

        do {
            _ = try await context.repository.applyRecordingCommand(
                sessionID: session.sessionID,
                command: .pause
            )
            Issue.record("affected-row 0 update가 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .conditionalUpdateConflict)
        } catch {
            Issue.record("affected-row 0이 typed conflict가 아닙니다")
        }

        #expect(try await context.repository.session(sessionID: session.sessionID) == before)
    }

    @Test("update trigger failure는 typed write failure이고 partial state를 rollback한다")
    func updateFailureRollsBackTransaction() async throws {
        let context = try makeContext(times: [createdAt, createdAt.addingTimeInterval(1)])
        let before = try await context.repository.insert(lectureSession: session)
        try await context.database.pool.write { db in
            try db.execute(
                sql: """
                    CREATE TRIGGER fail_local_update
                    BEFORE UPDATE OF local_processing_state ON sessions
                    BEGIN
                        SELECT RAISE(ABORT, 'injected update failure');
                    END
                    """
            )
        }

        do {
            _ = try await context.repository.applyLocalProcessingCommand(
                sessionID: session.sessionID,
                command: .captureEndedSafely
            )
            Issue.record("trigger failure 이후 transaction이 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .databaseWriteFailed)
            #expect(error.errorDescription?.contains("injected") == false)
        } catch {
            Issue.record("raw database error가 boundary 밖으로 노출됐습니다")
        }

        #expect(try await context.repository.session(sessionID: session.sessionID) == before)
    }

    @Test("read-back mismatch는 transaction 전체를 rollback한다")
    func readBackMismatchRollsBackTransaction() async throws {
        let context = try makeContext(times: [createdAt, createdAt.addingTimeInterval(1)])
        let before = try await context.repository.insert(
            lectureSession: session,
            recordingState: .recording
        )
        try await context.database.pool.write { db in
            try db.execute(
                sql: """
                    CREATE TRIGGER mutate_identity_after_recording_update
                    AFTER UPDATE OF recording_state ON sessions
                    BEGIN
                        UPDATE sessions
                        SET lecture_local_minute = lecture_local_minute + 1
                        WHERE session_id = NEW.session_id;
                    END
                    """
            )
        }

        do {
            _ = try await context.repository.applyRecordingCommand(
                sessionID: session.sessionID,
                command: .pause
            )
            Issue.record("read-back identity mismatch가 commit되면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .transactionVerificationFailed)
        } catch {
            Issue.record("read-back mismatch가 typed error로 mapping되지 않았습니다")
        }

        #expect(try await context.repository.session(sessionID: session.sessionID) == before)
    }

    @Test("insert trigger failure는 row를 남기지 않는다")
    func insertFailureRollsBackTransaction() async throws {
        let context = try makeContext(times: [createdAt])
        try await context.database.pool.write { db in
            try db.execute(
                sql: """
                    CREATE TRIGGER fail_session_insert
                    AFTER INSERT ON sessions
                    BEGIN
                        SELECT RAISE(ABORT, 'injected insert failure');
                    END
                    """
            )
        }

        do {
            _ = try await context.repository.insert(lectureSession: session)
            Issue.record("insert trigger failure가 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .databaseWriteFailed)
        } catch {
            Issue.record("insert failure가 typed persistence error가 아닙니다")
        }

        #expect(try rowCount(in: context.database) == 0)
    }

    @Test("database read failure는 raw SQL 없이 typed error로 mapping한다")
    func databaseReadFailureIsTyped() async throws {
        let context = try makeContext(times: [createdAt])
        try await context.database.pool.write { db in
            try db.drop(table: SessionRecord.databaseTableName)
        }

        do {
            _ = try await context.repository.session(sessionID: session.sessionID)
            Issue.record("sessions table 부재에서 lookup이 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .databaseReadFailed)
            #expect(error.errorDescription?.contains("sessions") == false)
        } catch {
            Issue.record("raw database read error가 boundary 밖으로 노출됐습니다")
        }
    }

    @Test("database reopen 후에도 저장된 transition 결과를 유지한다")
    func persistedResultSurvivesReopen() async throws {
        let updatedAt = createdAt.addingTimeInterval(1)
        let context = try makeContext(times: [createdAt, updatedAt])
        _ = try await context.repository.insert(
            lectureSession: session,
            recordingState: .recording
        )
        let expected = try await context.repository.applyRecordingCommand(
            sessionID: session.sessionID,
            command: .pause
        )

        let reopenedDatabase = try AppDatabase.open(at: context.temporary.databaseURL)
        let reopenedRepository = SessionRepository(database: reopenedDatabase)
        let reopened = try await reopenedRepository.session(sessionID: session.sessionID)

        #expect(reopened == expected)
        #expect(reopened.recordingState == .paused)
        #expect(reopened.updatedAt == updatedAt)
        try reopenedDatabase.pool.close()
    }

    @Test("repository actor와 snapshot은 Swift 6 Sendable 경계를 만족한다")
    func valuesAreSendable() async throws {
        let context = try makeContext(times: [createdAt])
        let snapshot = try await context.repository.insert(lectureSession: session)

        requireSendable(context.repository)
        requireSendable(snapshot)
        let transferred = await Task.detached { snapshot }.value

        #expect(transferred == snapshot)
    }

    private func makeContext(times: [Date]) throws -> RepositoryTestContext {
        let temporary = try RepositoryTemporaryDatabase()
        let database = try AppDatabase.open(at: temporary.databaseURL)
        let clock = LockedClock(times: times)
        let repository = SessionRepository(database: database, now: clock.next)
        return RepositoryTestContext(
            temporary: temporary,
            database: database,
            repository: repository
        )
    }

    private func rowCount(in database: AppDatabase) throws -> Int {
        try database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sessions") ?? -1
        }
    }

    private func rawRecord(
        in database: AppDatabase,
        sessionID: String
    ) throws -> SessionRecord {
        try database.pool.read { db in
            guard let record = try SessionRecord.fetchOne(db, key: sessionID) else {
                throw MissingRawRecord()
            }
            return record
        }
    }

    private func corrupt(
        column: String,
        value: String,
        sessionID: String,
        database: AppDatabase
    ) throws {
        try database.pool.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            defer { try? db.execute(sql: "PRAGMA ignore_check_constraints = OFF") }
            try db.execute(
                sql: "UPDATE sessions SET \(column) = ? WHERE session_id = ?",
                arguments: [value, sessionID]
            )
        }
    }

    private func assertMetadataUnchanged(
        from before: SessionSnapshot,
        to after: SessionSnapshot
    ) {
        #expect(after.lastVerifiedStage == before.lastVerifiedStage)
        #expect(after.canonicalPath == before.canonicalPath)
        #expect(after.title == before.title)
        #expect(after.failureCategory == before.failureCategory)
        #expect(after.failureCode == before.failureCode)
        #expect(after.discardRequested == before.discardRequested)
        #expect(after.attemptCount == before.attemptCount)
        #expect(after.lastAttemptedAt == before.lastAttemptedAt)
    }

    private func recordingOutcome(
        repository: SessionRepository,
        sessionID: String,
        command: SessionCommand
    ) async -> RecordingOutcome {
        do {
            _ = try await repository.applyRecordingCommand(
                sessionID: sessionID,
                command: command
            )
            return .success
        } catch is DomainError {
            return .invalidTransition
        } catch {
            return .unexpectedFailure
        }
    }

    private func requireSendable<T: Sendable>(_ value: T) {
        _ = value
    }
}

private enum RecordingOutcome: Equatable, Sendable {
    case success
    case invalidTransition
    case unexpectedFailure
}

private struct MissingRawRecord: Error {}

private final class LockedClock: @unchecked Sendable {
    private let lock = NSLock()
    private let times: [Date]
    private var index = 0

    init(times: [Date]) {
        precondition(!times.isEmpty)
        self.times = times
    }

    func next() -> Date {
        lock.withLock {
            precondition(index < times.count, "test clock가 예상보다 많이 호출됐습니다")
            defer { index += 1 }
            return times[index]
        }
    }
}

private final class RepositoryTemporaryDatabase {
    let directoryURL: URL
    let databaseURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClassHelperRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        databaseURL = directoryURL.appendingPathComponent("repository.sqlite", isDirectory: false)
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private final class RepositoryTestContext {
    let temporary: RepositoryTemporaryDatabase
    let database: AppDatabase
    let repository: SessionRepository

    init(
        temporary: RepositoryTemporaryDatabase,
        database: AppDatabase,
        repository: SessionRepository
    ) {
        self.temporary = temporary
        self.database = database
        self.repository = repository
    }

    deinit {
        try? database.pool.close()
    }
}
