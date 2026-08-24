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
    case sessionNotFound
    case duplicateSessionIdentity
    case invalidPersistedSession
    case invalidPersistedRecordingState
    case invalidPersistedLocalProcessingState
    case invalidPersistedPublicationState
    case invalidPersistedTimestamp
    case conditionalUpdateConflict
    case transactionVerificationFailed
    case databaseReadFailed
    case databaseWriteFailed
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
        case .sessionNotFound:
            "저장된 세션을 찾을 수 없습니다."
        case .duplicateSessionIdentity:
            "같은 세션 식별자가 이미 저장되어 있습니다."
        case .invalidPersistedSession:
            "저장된 세션 정보를 읽을 수 없습니다."
        case .invalidPersistedRecordingState:
            "저장된 녹음 상태를 읽을 수 없습니다."
        case .invalidPersistedLocalProcessingState:
            "저장된 로컬 처리 상태를 읽을 수 없습니다."
        case .invalidPersistedPublicationState:
            "저장된 게시 상태를 읽을 수 없습니다."
        case .invalidPersistedTimestamp:
            "저장된 세션 시각을 읽을 수 없습니다."
        case .conditionalUpdateConflict:
            "세션 상태가 예상과 달라 갱신하지 않았습니다."
        case .transactionVerificationFailed:
            "세션 갱신 결과를 안전하게 확인할 수 없습니다."
        case .databaseReadFailed:
            "세션 정보를 읽을 수 없습니다."
        case .databaseWriteFailed:
            "세션 정보를 안전하게 저장할 수 없습니다."
        }
    }
}
