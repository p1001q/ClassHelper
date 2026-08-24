//
//  PersistenceError.swift
//  ClassHelper
//

import Foundation

nonisolated enum PersistenceError: Error, Equatable, Sendable {
    case databaseOpenFailed
    case databaseConfigurationFailed
    case migrationFailed
    case integrityCheckFailed
    case invalidPersistedSession
}

extension PersistenceError: LocalizedError {
    nonisolated var errorDescription: String? {
        switch self {
        case .databaseOpenFailed:
            "데이터베이스를 열 수 없습니다."
        case .databaseConfigurationFailed:
            "데이터베이스 안전 설정을 적용할 수 없습니다."
        case .migrationFailed:
            "데이터베이스 스키마를 준비할 수 없습니다."
        case .integrityCheckFailed:
            "데이터베이스 무결성을 확인할 수 없습니다."
        case .invalidPersistedSession:
            "저장된 세션 정보를 읽을 수 없습니다."
        }
    }
}
