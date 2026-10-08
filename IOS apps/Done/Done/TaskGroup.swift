//
//  TaskGroup.swift
//  Done
//
//  Created by Codex on 3/12/26.
//

import Foundation

struct TaskGroup: Identifiable, Hashable {
    let id: String
    var name: String
    var details: String
    let inviteCode: String
    let ownerUserRecordName: String
    let createdAt: Date
    let isOwnedByCurrentUser: Bool

    init(
        id: String,
        name: String,
        details: String,
        inviteCode: String,
        ownerUserRecordName: String,
        createdAt: Date,
        isOwnedByCurrentUser: Bool
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.inviteCode = inviteCode
        self.ownerUserRecordName = ownerUserRecordName
        self.createdAt = createdAt
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
    }
}
