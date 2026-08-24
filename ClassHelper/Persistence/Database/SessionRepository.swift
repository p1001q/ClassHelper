//
//  SessionRepository.swift
//  ClassHelper
//

import Foundation
import GRDB

nonisolated struct SessionSnapshot: Equatable, Sendable {
    let lectureSession: LectureSession
    let recordingState: RecordingState
    let localProcessingState: LocalProcessingState
    let publicationState: PublicationState
    let lastVerifiedStage: String?
    let canonicalPath: String?
    let title: String?
    let failureCategory: String?
    let failureCode: String?
    let discardRequested: Bool
    let attemptCount: Int?
    let lastAttemptedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

actor SessionRepository {
    typealias Clock = @Sendable () -> Date

    private let database: AppDatabase
    private let now: Clock

    init(
        database: AppDatabase,
        now: @escaping Clock = { Date() }
    ) {
        self.database = database
        self.now = now
    }

    func insert(
        lectureSession: LectureSession,
        recordingState: RecordingState = .ready,
        localProcessingState: LocalProcessingState = .capturing,
        publicationState: PublicationState = .notApplicable
    ) throws -> SessionSnapshot {
        let timestamp = now()
        let record = SessionRecord(
            lectureSession: lectureSession,
            recordingState: recordingState,
            localProcessingState: localProcessingState,
            publicationState: publicationState,
            discardRequested: false,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        do {
            return try database.pool.write { db in
                if try Self.fetchRecord(db, sessionID: lectureSession.sessionID) != nil {
                    throw PersistenceError.duplicateSessionIdentity
                }

                do {
                    try record.insert(db)
                } catch let error as DatabaseError {
                    if Self.isDuplicateIdentityConstraint(error) {
                        throw PersistenceError.duplicateSessionIdentity
                    }
                    throw PersistenceError.databaseWriteFailed
                } catch {
                    throw PersistenceError.databaseWriteFailed
                }

                guard let inserted = try Self.fetchRecord(db, sessionID: lectureSession.sessionID) else {
                    throw PersistenceError.transactionVerificationFailed
                }
                guard inserted == record else {
                    throw PersistenceError.transactionVerificationFailed
                }
                return try inserted.snapshot()
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.databaseWriteFailed
        }
    }

    func session(sessionID: String) throws -> SessionSnapshot {
        do {
            return try database.pool.read { db in
                guard let record = try Self.fetchRecord(db, sessionID: sessionID) else {
                    throw PersistenceError.sessionNotFound
                }
                return try record.snapshot()
            }
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.databaseReadFailed
        }
    }

    func applyRecordingCommand(
        sessionID: String,
        command: SessionCommand
    ) throws -> SessionSnapshot {
        let timestampProvider = now

        do {
            return try database.pool.write { db in
                guard let current = try Self.fetchRecord(db, sessionID: sessionID) else {
                    throw PersistenceError.sessionNotFound
                }
                let currentSnapshot = try current.snapshot()
                let nextState = try RecordingTransitionPolicy.transition(
                    from: currentSnapshot.recordingState,
                    command: command
                )
                let updatedAt = SessionRecord.encode(timestampProvider())

                let updatedCount: Int
                do {
                    updatedCount = try SessionRecord
                        .filter(key: sessionID)
                        .filter(Column("recording_state") == current.recordingState)
                        .updateAll(
                            db,
                            Column("recording_state").set(to: nextState.rawValue),
                            Column("updated_at").set(to: updatedAt)
                        )
                } catch {
                    throw PersistenceError.databaseWriteFailed
                }
                guard updatedCount == 1 else {
                    throw PersistenceError.conditionalUpdateConflict
                }

                guard let updated = try Self.fetchRecord(db, sessionID: sessionID) else {
                    throw PersistenceError.transactionVerificationFailed
                }
                var expected = current
                expected.recordingState = nextState.rawValue
                expected.updatedAt = updatedAt
                guard updated == expected else {
                    throw PersistenceError.transactionVerificationFailed
                }
                return try updated.snapshot()
            }
        } catch let error as DomainError {
            throw error
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.databaseWriteFailed
        }
    }

    func applyLocalProcessingCommand(
        sessionID: String,
        command: LocalProcessingCommand
    ) throws -> SessionSnapshot {
        let timestampProvider = now

        do {
            return try database.pool.write { db in
                guard let current = try Self.fetchRecord(db, sessionID: sessionID) else {
                    throw PersistenceError.sessionNotFound
                }
                let currentSnapshot = try current.snapshot()
                let nextState = try LocalProcessingTransitionPolicy.transition(
                    from: currentSnapshot.localProcessingState,
                    command: command
                )
                let updatedAt = SessionRecord.encode(timestampProvider())

                let updatedCount: Int
                do {
                    updatedCount = try SessionRecord
                        .filter(key: sessionID)
                        .filter(Column("local_processing_state") == current.localProcessingState)
                        .updateAll(
                            db,
                            Column("local_processing_state").set(to: nextState.rawValue),
                            Column("updated_at").set(to: updatedAt)
                        )
                } catch {
                    throw PersistenceError.databaseWriteFailed
                }
                guard updatedCount == 1 else {
                    throw PersistenceError.conditionalUpdateConflict
                }

                guard let updated = try Self.fetchRecord(db, sessionID: sessionID) else {
                    throw PersistenceError.transactionVerificationFailed
                }
                var expected = current
                expected.localProcessingState = nextState.rawValue
                expected.updatedAt = updatedAt
                guard updated == expected else {
                    throw PersistenceError.transactionVerificationFailed
                }
                return try updated.snapshot()
            }
        } catch let error as DomainError {
            throw error
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.databaseWriteFailed
        }
    }

    private nonisolated static func fetchRecord(
        _ db: Database,
        sessionID: String
    ) throws -> SessionRecord? {
        do {
            return try SessionRecord.fetchOne(db, key: sessionID)
        } catch {
            throw PersistenceError.databaseReadFailed
        }
    }

    private nonisolated static func isDuplicateIdentityConstraint(
        _ error: DatabaseError
    ) -> Bool {
        error.extendedResultCode == .SQLITE_CONSTRAINT_PRIMARYKEY
            || error.extendedResultCode == .SQLITE_CONSTRAINT_UNIQUE
    }
}
