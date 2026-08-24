//
//  AppDatabase.swift
//  ClassHelper
//

import Foundation
import GRDB

nonisolated final class AppDatabase: @unchecked Sendable {
    typealias IntegrityValidator = @Sendable (DatabasePool) throws -> Void

    let pool: DatabasePool

    static func open(at url: URL) throws -> AppDatabase {
        try open(at: url, migrator: AppDatabaseMigrator.make())
    }

    static func open(
        at url: URL,
        migrator: DatabaseMigrator,
        integrityValidator: IntegrityValidator = validateIntegrity,
        onReady: @Sendable () -> Void = {}
    ) throws -> AppDatabase {
        let pool: DatabasePool
        do {
            var configuration = Configuration()
            configuration.prepareDatabase { db in
                do {
                    try db.execute(sql: "PRAGMA foreign_keys = ON")
                    guard try Int.fetchOne(db, sql: "PRAGMA foreign_keys") == 1 else {
                        throw ConfigurationFailure()
                    }
                } catch is ConfigurationFailure {
                    throw ConfigurationFailure()
                } catch {
                    throw ConfigurationFailure()
                }
            }
            pool = try DatabasePool(path: url.path, configuration: configuration)
        } catch is ConfigurationFailure {
            throw PersistenceError.databaseConfigurationFailed
        } catch {
            throw PersistenceError.databaseOpenFailed
        }

        do {
            try migrator.migrate(pool)
        } catch {
            throw PersistenceError.migrationFailed
        }

        do {
            try validateConfiguration(pool)
        } catch {
            throw PersistenceError.databaseConfigurationFailed
        }

        do {
            try integrityValidator(pool)
        } catch {
            throw PersistenceError.integrityCheckFailed
        }

        let database = AppDatabase(pool: pool)
        onReady()
        return database
    }

    private init(pool: DatabasePool) {
        self.pool = pool
    }

    private static func validateConfiguration(_ pool: DatabasePool) throws {
        try pool.read { db in
            guard
                try String.fetchOne(db, sql: "PRAGMA journal_mode")?.lowercased() == "wal",
                try Int.fetchOne(db, sql: "PRAGMA foreign_keys") == 1
            else {
                throw ConfigurationFailure()
            }
        }
    }

    private static func validateIntegrity(_ pool: DatabasePool) throws {
        try pool.read { db in
            let results = try String.fetchAll(db, sql: "PRAGMA integrity_check")
            guard results == ["ok"] else {
                throw IntegrityFailure()
            }
        }
    }
}

private nonisolated struct ConfigurationFailure: Error {}
private nonisolated struct IntegrityFailure: Error {}
