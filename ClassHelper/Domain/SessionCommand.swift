//
//  SessionCommand.swift
//  ClassHelper
//

nonisolated enum SessionCommand: CaseIterable, Sendable {
    case start
    case startCommitted
    case startFailed
    case startBlocked
    case pause
    case resume
    case stop
    case stopCommitted
}
