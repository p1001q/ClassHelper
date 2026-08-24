//
//  AppDatabaseTests.swift
//  ClassHelperTests
//

import Foundation
import GRDB
import Testing
@testable import ClassHelper

@Suite("GRDB operational database", .serialized)
struct AppDatabaseTests {
    @Test("fresh open은 v1을 적용하고 reopen에도 migration을 중복 적용하지 않는다")
    func freshOpenAndIdempotentReopen() throws {
        let temporary = try TemporaryDatabase()
        let first = try AppDatabase.open(at: temporary.databaseURL)
        let migrator = AppDatabaseMigrator.make()

        #expect(try first.pool.read { try migrator.appliedIdentifiers($0) } == [AppDatabaseMigrator.v1SessionsIdentifier])
        #expect(try first.pool.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM sessions") } == 0)

        let reopened = try AppDatabase.open(at: temporary.databaseURL)
        #expect(try reopened.pool.read { try migrator.appliedIdentifiers($0) } == [AppDatabaseMigrator.v1SessionsIdentifier])
        #expect(try reopened.pool.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM sessions") } == 0)
        try reopened.pool.close()
        try first.pool.close()
    }

    @Test("WAL, foreign keys와 integrity check가 실제 connection에서 활성화된다")
    func validatesConfigurationAndIntegrity() throws {
        let context = try makeDatabase()
        let database = context.database

        let values = try database.pool.read { db in
            (
                try String.fetchOne(db, sql: "PRAGMA journal_mode")?.lowercased(),
                try Int.fetchOne(db, sql: "PRAGMA foreign_keys"),
                try String.fetchAll(db, sql: "PRAGMA integrity_check")
            )
        }
        let writerForeignKeys = try database.pool.write { db in
            try Int.fetchOne(db, sql: "PRAGMA foreign_keys")
        }

        #expect(values.0 == "wal")
        #expect(values.1 == 1)
        #expect(values.2 == ["ok"])
        #expect(writerForeignKeys == 1)
    }

    @Test("sessions schema는 필수 column만 포함하고 강의 content column은 포함하지 않는다")
    func schemaColumns() throws {
        let context = try makeDatabase()
        let database = context.database
        let names = try database.pool.read { db in
            Set(try db.columns(in: SessionRecord.databaseTableName).map(\.name))
        }
        let required: Set<String> = [
            "session_id", "lecture_started_at", "lecture_timezone", "lecture_local_date",
            "lecture_local_year", "lecture_local_month", "lecture_local_day",
            "lecture_local_hour", "lecture_local_minute", "recording_state",
            "local_processing_state", "publication_state", "last_verified_stage",
            "canonical_path", "title", "failure_category", "failure_code",
            "discard_requested", "attempt_count", "last_attempted_at", "created_at", "updated_at",
        ]
        let forbidden: Set<String> = [
            "transcript", "transcript_text", "note", "note_body", "audio", "audio_data",
            "secret", "api_key", "token",
        ]

        #expect(names == required)
        #expect(names.isDisjoint(with: forbidden))
    }

    @Test("session identity/time, enum raw value와 SQLite boolean이 round-trip 된다")
    func roundTrip() throws {
        let context = try makeDatabase()
        let database = context.database
        let session = LectureSession(
            sessionID: UUID(uuidString: "A1B2C3D4-E5F6-4789-ABCD-0123456789AB")!,
            lectureStartedAt: Date(timeIntervalSince1970: 1_786_032_930.125),
            lectureTimeZone: TimeZone(identifier: "Asia/Seoul")!
        )
        let timestamp = Date(timeIntervalSince1970: 1_786_033_000.25)
        let record = SessionRecord(
            lectureSession: session,
            recordingState: .recording,
            localProcessingState: .capturing,
            publicationState: .notApplicable,
            lastVerifiedStage: "capture_committed",
            canonicalPath: nil,
            title: nil,
            failureCategory: nil,
            failureCode: nil,
            discardRequested: false,
            attemptCount: 0,
            lastAttemptedAt: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try database.pool.write { db in try record.insert(db) }
        let fetchedRecord = try database.pool.read { db in
            try SessionRecord.fetchOne(db, key: session.sessionID)
        }
        let fetched = try #require(fetchedRecord)
        let storedBoolean = try database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT discard_requested FROM sessions WHERE session_id = ?", arguments: [session.sessionID])
        }

        #expect(try fetched.lectureSession() == session)
        #expect(fetched.recordingState == RecordingState.recording.rawValue)
        #expect(fetched.localProcessingState == LocalProcessingState.capturing.rawValue)
        #expect(fetched.publicationState == PublicationState.notApplicable.rawValue)
        #expect(storedBoolean == 0)
    }

    @Test("database constraint가 duplicate identity와 invalid state를 거부한다")
    func rejectsDuplicateAndInvalidStates() throws {
        let context = try makeDatabase()
        let database = context.database
        try insertRaw(into: database, sessionID: "duplicate", canonicalPath: nil)

        #expect(throws: (any Error).self) {
            try insertRaw(into: database, sessionID: "duplicate", canonicalPath: nil)
        }
        for invalid in ["INVALID_RECORDING", "INVALID_LOCAL", "INVALID_PUBLICATION"] {
            #expect(throws: (any Error).self) {
                try insertRaw(
                    into: database,
                    sessionID: invalid.lowercased(),
                    canonicalPath: nil,
                    recordingState: invalid == "INVALID_RECORDING" ? invalid : RecordingState.ready.rawValue,
                    localState: invalid == "INVALID_LOCAL" ? invalid : LocalProcessingState.capturing.rawValue,
                    publicationState: invalid == "INVALID_PUBLICATION" ? invalid : PublicationState.notApplicable.rawValue
                )
            }
        }
    }

    @Test("partial unique canonical path는 여러 NULL과 서로 다른 path만 허용한다")
    func canonicalPathPartialUniqueness() throws {
        let context = try makeDatabase()
        let database = context.database
        try insertRaw(into: database, sessionID: "null-1", canonicalPath: nil)
        try insertRaw(into: database, sessionID: "null-2", canonicalPath: nil)
        try insertRaw(into: database, sessionID: "path-1", canonicalPath: "notes/one.md")
        try insertRaw(into: database, sessionID: "path-2", canonicalPath: "notes/two.md")

        #expect(throws: (any Error).self) {
            try insertRaw(into: database, sessionID: "path-duplicate", canonicalPath: "notes/one.md")
        }
        #expect(try database.pool.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM sessions") } == 4)
    }

    @Test("migration 실패는 typed error이고 ready 후속 work를 시작하지 않는다")
    func migrationFailureFailsClosed() throws {
        let temporary = try TemporaryDatabase()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("injected_failure") { db in
            try db.create(table: "injected_partial") { $0.column("id", .integer) }
            throw InjectedFailure()
        }
        let ready = LockedFlag()

        #expect(throws: ClassHelper.PersistenceError.migrationFailed) {
            try AppDatabase.open(
                at: temporary.databaseURL,
                migrator: migrator,
                onReady: { ready.set() }
            )
        }
        #expect(!ready.value)

        let inspection = try DatabaseQueue(path: temporary.databaseURL.path)
        #expect(try inspection.read { try !$0.tableExists("injected_partial") })
        #expect(try inspection.read { try migrator.appliedIdentifiers($0).isEmpty })
    }

    @Test("integrity 실패는 typed error이고 ready 후속 work를 시작하지 않는다")
    func integrityFailureFailsClosed() throws {
        let temporary = try TemporaryDatabase()
        let ready = LockedFlag()

        #expect(throws: ClassHelper.PersistenceError.integrityCheckFailed) {
            try AppDatabase.open(
                at: temporary.databaseURL,
                migrator: AppDatabaseMigrator.make(),
                integrityValidator: { _ in throw InjectedFailure() },
                onReady: { ready.set() }
            )
        }
        #expect(!ready.value)
    }

    @Test("open 실패는 typed error이고 ready 후속 work를 시작하지 않는다")
    func openFailureFailsClosed() throws {
        let temporary = try TemporaryDatabase()
        let ready = LockedFlag()

        #expect(throws: ClassHelper.PersistenceError.databaseOpenFailed) {
            try AppDatabase.open(
                at: temporary.directoryURL,
                migrator: AppDatabaseMigrator.make(),
                onReady: { ready.set() }
            )
        }
        #expect(!ready.value)
    }

    @Test("corrupt database는 typed failure 후에도 삭제하거나 재생성하지 않는다")
    func corruptDatabaseIsPreserved() throws {
        let temporary = try TemporaryDatabase()
        let original = Data("synthetic-not-a-sqlite-database".utf8)
        try original.write(to: temporary.databaseURL)
        let ready = LockedFlag()

        do {
            _ = try AppDatabase.open(
                    at: temporary.databaseURL,
                    migrator: AppDatabaseMigrator.make(),
                    onReady: { ready.set() }
                )
            Issue.record("corrupt database open이 성공하면 안 됩니다")
        } catch let error as ClassHelper.PersistenceError {
            #expect(error == .databaseOpenFailed || error == .migrationFailed)
        } catch {
            Issue.record("raw database error가 노출됐습니다: \(type(of: error))")
        }
        #expect(!ready.value)
        #expect(FileManager.default.fileExists(atPath: temporary.databaseURL.path))
        #expect(try Data(contentsOf: temporary.databaseURL) == original)
    }

    private func makeDatabase() throws -> TestDatabaseContext {
        let temporary = try TemporaryDatabase()
        let database = try AppDatabase.open(at: temporary.databaseURL)
        return TestDatabaseContext(temporary: temporary, database: database)
    }

    private func insertRaw(
        into database: AppDatabase,
        sessionID: String,
        canonicalPath: String?,
        recordingState: String = RecordingState.ready.rawValue,
        localState: String = LocalProcessingState.capturing.rawValue,
        publicationState: String = PublicationState.notApplicable.rawValue
    ) throws {
        try database.pool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO sessions (
                        session_id, lecture_started_at, lecture_timezone, lecture_local_date,
                        lecture_local_year, lecture_local_month, lecture_local_day,
                        lecture_local_hour, lecture_local_minute, recording_state,
                        local_processing_state, publication_state, canonical_path,
                        discard_requested, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    sessionID, "2026-08-24T00:00:00.000Z", "Asia/Seoul", "2026-08-24",
                    2026, 8, 24, 9, 0, recordingState, localState, publicationState,
                    canonicalPath, false, "2026-08-24T00:00:00.000Z", "2026-08-24T00:00:00.000Z",
                ]
            )
        }
    }
}

private final class TemporaryDatabase {
    let directoryURL: URL
    let databaseURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClassHelperTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        databaseURL = directoryURL.appendingPathComponent("operational.sqlite", isDirectory: false)
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private final class TestDatabaseContext {
    let temporary: TemporaryDatabase
    let database: AppDatabase

    init(temporary: TemporaryDatabase, database: AppDatabase) {
        self.temporary = temporary
        self.database = database
    }

    deinit {
        try? database.pool.close()
    }
}

private struct InjectedFailure: Error {}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    var value: Bool {
        lock.withLock { storage }
    }

    func set() {
        lock.withLock { storage = true }
    }
}
