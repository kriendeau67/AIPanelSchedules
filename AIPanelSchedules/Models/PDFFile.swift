//
//  PDFFile.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//
import Foundation

struct PDFFile: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var fileName: String
    var uploadedAt: Date
    var urlString: String?

    // 🚀 NEW FIELD
    var excelUrl: String?
    var excelLocked: Bool?
    var lockedAt: Date?
    var unlockedAt: Date?
    var url: URL? {
        guard let urlString = urlString else { return nil }
        return URL(string: urlString)
    }

    // 🚀 Convenience
    var excelURL: URL? {
        guard let excelUrl = excelUrl else { return nil }
        return URL(string: excelUrl)
    }
    init(
        id: String = UUID().uuidString,
        fileName: String,
        uploadedAt: Date,
        urlString: String?,
        excelUrl: String? = nil,
        excelLocked: Bool? = nil,
        lockedAt: Date? = nil,
        unlockedAt: Date? = nil
    )
    {
        self.id = id
        self.fileName = fileName
        self.uploadedAt = uploadedAt
        self.urlString = urlString
        self.excelUrl = excelUrl
        self.excelLocked = excelLocked
        self.lockedAt = lockedAt
        self.unlockedAt = unlockedAt
    }
}
