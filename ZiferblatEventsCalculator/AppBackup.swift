// AppBackup.swift
import Foundation

struct AppBackup: Codable {
    var events: [Event]
    var instances: [EventInstance]
    var exportedAt: Date = Date()
}
