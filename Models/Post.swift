// Models/Post.swift

import Foundation

struct Post: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let centerNodeText: String
    var likeCount: Int
    var commentCount: Int
    let isDeleted: Bool
    var isPinned: Bool
    var visibility: String
    var commentsEnabled: Bool
    var allowSave: Bool
    var hideLikeCount: Bool
    let createdAt: Date
    let updatedAt: Date
    var style: String?
    var currentEdition: Int  // 追加: 現在の編集回数

    // フィード表示設定
    var displayScale: Double
    var displayOffsetX: Double
    var displayOffsetY: Double

    // リレーション
    var user: User?
    var nodes: [Node]?
    var connections: [NodeConnection]?
    
    var isPublic: Bool {
        get { visibility == "public" }
        set { visibility = newValue ? "public" : "followers_only" }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case centerNodeText = "center_node_text"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isDeleted = "is_deleted"
        case isPinned = "is_pinned"
        case allowSave = "allow_save"
        case visibility
        case commentsEnabled = "comments_enabled"
        case hideLikeCount = "hide_like_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user
        case nodes
        case connections
        case style
        case currentEdition = "current_edition"
        case displayScale = "display_scale"
        case displayOffsetX = "display_offset_x"
        case displayOffsetY = "display_offset_y"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        centerNodeText = try container.decode(String.self, forKey: .centerNodeText)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        allowSave = try container.decodeIfPresent(Bool.self, forKey: .allowSave) ?? true
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? "public"
        commentsEnabled = try container.decodeIfPresent(Bool.self, forKey: .commentsEnabled) ?? true
        hideLikeCount = try container.decodeIfPresent(Bool.self, forKey: .hideLikeCount) ?? false
        currentEdition = try container.decodeIfPresent(Int.self, forKey: .currentEdition) ?? 1
        displayScale = try container.decodeIfPresent(Double.self, forKey: .displayScale) ?? 1.0
        displayOffsetX = try container.decodeIfPresent(Double.self, forKey: .displayOffsetX) ?? 0
        displayOffsetY = try container.decodeIfPresent(Double.self, forKey: .displayOffsetY) ?? 0

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
        
        user = try container.decodeIfPresent(User.self, forKey: .user)
        nodes = try container.decodeIfPresent([Node].self, forKey: .nodes)
        connections = try container.decodeIfPresent([NodeConnection].self, forKey: .connections)
        style = try container.decodeIfPresent(String.self, forKey: .style)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(centerNodeText, forKey: .centerNodeText)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(commentCount, forKey: .commentCount)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(commentsEnabled, forKey: .commentsEnabled)
        try container.encode(allowSave, forKey: .allowSave)
        try container.encode(hideLikeCount, forKey: .hideLikeCount)
        try container.encode(currentEdition, forKey: .currentEdition)
        try container.encode(displayScale, forKey: .displayScale)
        try container.encode(displayOffsetX, forKey: .displayOffsetX)
        try container.encode(displayOffsetY, forKey: .displayOffsetY)
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        centerNodeText: String,
        likeCount: Int = 0,
        commentCount: Int = 0,
        isDeleted: Bool = false,
        isPinned: Bool = false,
        visibility: String = "public",
        commentsEnabled: Bool = true,
        allowSave: Bool = true,
        hideLikeCount: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        user: User? = nil,
        nodes: [Node]? = nil,
        connections: [NodeConnection]? = nil,
        currentEdition: Int = 1,
        displayScale: Double = 1.0,
        displayOffsetX: Double = 0,
        displayOffsetY: Double = 0
    ) {
        self.id = id
        self.userId = userId
        self.centerNodeText = centerNodeText
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isDeleted = isDeleted
        self.isPinned = isPinned
        self.visibility = visibility
        self.commentsEnabled = commentsEnabled
        self.allowSave = allowSave
        self.hideLikeCount = hideLikeCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.user = user
        self.nodes = nodes
        self.connections = connections
        self.currentEdition = currentEdition
        self.displayScale = displayScale
        self.displayOffsetX = displayOffsetX
        self.displayOffsetY = displayOffsetY
    }
}
