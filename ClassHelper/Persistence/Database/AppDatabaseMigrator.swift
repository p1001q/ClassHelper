//
//  AppDatabaseMigrator.swift
//  ClassHelper
//

import Foundation
import GRDB

nonisolated enum AppDatabaseMigrator {
    static let v1SessionsIdentifier = "v1_sessions"

    static func make() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration(v1SessionsIdentifier) { db in
            try db.create(table: SessionRecord.databaseTableName) { table in
                table.column("session_id", .text).primaryKey()
                table.column("lecture_started_at", .text).notNull()
                table.column("lecture_timezone", .text).notNull()
                table.column("lecture_local_date", .text).notNull()
                table.column("lecture_local_year", .integer).notNull()
                table.column("lecture_local_month", .integer).notNull()
                table.column("lecture_local_day", .integer).notNull()
                table.column("lecture_local_hour", .integer).notNull()
                table.column("lecture_local_minute", .integer).notNull()
                table.column("recording_state", .text).notNull()
                    .check(sql: Self.allowedValuesSQL("recording_state", RecordingState.allCases.map(\.rawValue)))
                table.column("local_processing_state", .text).notNull()
                    .check(sql: Self.allowedValuesSQL("local_processing_state", LocalProcessingState.allCases.map(\.rawValue)))
                table.column("publication_state", .text).notNull()
                    .check(sql: Self.allowedValuesSQL("publication_state", PublicationState.allCases.map(\.rawValue)))
                table.column("last_verified_stage", .text)
                table.column("canonical_path", .text)
                table.column("title", .text)
                table.column("failure_category", .text)
                table.column("failure_code", .text)
                table.column("discard_requested", .integer).notNull()
                    .check(sql: "discard_requested IN (0, 1)")
                table.column("attempt_count", .integer)
                    .check(sql: "attempt_count IS NULL OR attempt_count >= 0")
                table.column("last_attempted_at", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }

            try db.create(
                index: "sessions_canonical_path_unique",
                on: SessionRecord.databaseTableName,
                columns: ["canonical_path"],
                options: .unique,
                condition: Column("canonical_path") != nil
            )
        }
        return migrator
    }

    private static func allowedValuesSQL(_ column: String, _ values: [String]) -> String {
        let quoted = values.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }
        return "\(column) IN (\(quoted.joined(separator: ", ")))"
    }
}
