//
//  SessionCommand.swift
//  ClassHelper
//

nonisolated enum SessionCommand: Sendable {
    case start
    case startCommitted
    case pause
    case resume
    case stop
    case stopCommitted
}
