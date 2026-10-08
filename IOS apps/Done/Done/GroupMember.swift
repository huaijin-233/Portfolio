//
//  GroupMember.swift
//  Done
//
//  Created by Codex on 3/14/26.
//

import Foundation

struct GroupMember: Identifiable, Hashable {
    let id: String
    let groupCode: String
    let userRecordName: String
    let displayName: String
    let joinedAt: Date
    let isOwner: Bool
}
