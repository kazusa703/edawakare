// Models/User.swift

import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    let email: String
    var username: String
    var displayName: String
    var bio: String?
    var avatarUrl: String?
    var totalBranches: Int
    var isPrivate: Bool
    var dmPermission: String
    var iconBorderColor: String?
    var iconBorderChangedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    // 追加プロパティ（計算またはJOINで取得）
    var followersCount: Int?
    var followingCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName = "display_name"
        case bio
        case avatarUrl = "avatar_url"
        case totalBranches = "total_branches"
        case isPrivate = "is_private"
        case dmPermission = "dm_permission"
        case iconBorderColor = "icon_border_color"
        case iconBorderChangedAt = "icon_border_changed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        totalBranches = try container.decodeIfPresent(Int.self, forKey: .totalBranches) ?? 0
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        dmPermission = try container.decodeIfPresent(String.self, forKey: .dmPermission) ?? "everyone"
        iconBorderColor = try container.decodeIfPresent(String.self, forKey: .iconBorderColor)

        if let dateString = try? container.decode(String.self, forKey: .iconBorderChangedAt) {
            iconBorderChangedAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            iconBorderChangedAt = nil
        }

        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }

        if let dateString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            updatedAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encode(totalBranches, forKey: .totalBranches)
        try container.encode(isPrivate, forKey: .isPrivate)
        try container.encode(dmPermission, forKey: .dmPermission)
        try container.encodeIfPresent(iconBorderColor, forKey: .iconBorderColor)
    }

    init(id: UUID, email: String, username: String, displayName: String, bio: String? = nil, avatarUrl: String? = nil, totalBranches: Int = 0, isPrivate: Bool = false, dmPermission: String = "everyone", iconBorderColor: String? = nil, iconBorderChangedAt: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarUrl = avatarUrl
        self.totalBranches = totalBranches
        self.isPrivate = isPrivate
        self.dmPermission = dmPermission
        self.iconBorderColor = iconBorderColor
        self.iconBorderChangedAt = iconBorderChangedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
