//
//  Assignment.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import Foundation

struct Assignment: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var isCompleted: Bool
    let createdAt: Date
    var groupCode: String?
    var groupName: String?
    var cloudRecordName: String?
    var creatorUserRecordName: String?

    var isGroupTask: Bool {
        groupCode != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case dueDate
        case isCompleted
        case createdAt
        case groupCode
        case groupName
        case cloudRecordName
        case creatorUserRecordName
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        groupCode: String? = nil,
        groupName: String? = nil,
        cloudRecordName: String? = nil,
        creatorUserRecordName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.groupCode = groupCode
        self.groupName = groupName
        self.cloudRecordName = cloudRecordName
        self.creatorUserRecordName = creatorUserRecordName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        groupCode = try container.decodeIfPresent(String.self, forKey: .groupCode)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        cloudRecordName = try container.decodeIfPresent(String.self, forKey: .cloudRecordName)
        creatorUserRecordName = try container.decodeIfPresent(String.self, forKey: .creatorUserRecordName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(groupCode, forKey: .groupCode)
        try container.encodeIfPresent(groupName, forKey: .groupName)
        try container.encodeIfPresent(cloudRecordName, forKey: .cloudRecordName)
        try container.encodeIfPresent(creatorUserRecordName, forKey: .creatorUserRecordName)
    }
}
