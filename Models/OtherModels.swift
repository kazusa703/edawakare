// Models/OtherModels.swift

import Foundation
import SwiftUI

// MARK: - Comment
struct Comment: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    let content: String
    let parentCommentId: UUID?
    var likeCount: Int
    let createdAt: Date
    var user: User?
    var replies: [Comment]? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case content
        case parentCommentId = "parent_comment_id"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        postId = try container.decode(UUID.self, forKey: .postId)
        content = try container.decode(String.self, forKey: .content)
        parentCommentId = try container.decodeIfPresent(UUID.self, forKey: .parentCommentId)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        user = try container.decodeIfPresent(User.self, forKey: .user)
        replies = nil

        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(postId, forKey: .postId)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(parentCommentId, forKey: .parentCommentId)
        try container.encode(likeCount, forKey: .likeCount)
    }

    init(id: UUID = UUID(), userId: UUID, postId: UUID, content: String, parentCommentId: UUID? = nil, likeCount: Int = 0, createdAt: Date = Date(), user: User? = nil, replies: [Comment]? = nil) {
        self.id = id
        self.userId = userId
        self.postId = postId
        self.content = content
        self.parentCommentId = parentCommentId
        self.likeCount = likeCount
        self.createdAt = createdAt
        self.user = user
        self.replies = replies
    }
}

// MARK: - Like
struct Like: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    enum CodingKeys: String, CodingKey { case id, userId = "user_id", postId = "post_id" }
}

// MARK: - Follow
struct Follow: Identifiable, Codable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    enum CodingKeys: String, CodingKey { case id, followerId = "follower_id", followingId = "following_id" }
}

// MARK: - Bookmark
struct Bookmark: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    var post: Post?
    enum CodingKeys: String, CodingKey { case id, userId = "user_id", postId = "post_id", post }
}

// MARK: - Block
struct Block: Identifiable, Codable {
    let id: UUID
    let blockerId: UUID
    let blockedId: UUID
    var blockedUser: User?
    
    enum CodingKeys: String, CodingKey {
        case id, blockerId = "blocker_id", blockedId = "blocked_id", blockedUser = "blocked"
    }
}

// MARK: - Report
struct Report: Identifiable, Codable {
    let id: UUID
    let reporterId: UUID
    let reportedUserId: UUID?
    let reportedPostId: UUID?
    let reason: String
    let detail: String?
    
    enum CodingKeys: String, CodingKey {
        case id, reporterId = "reporter_id", reportedUserId = "reported_user_id", reportedPostId = "reported_post_id", reason, detail
    }
}

// MARK: - Conversation
struct Conversation: Identifiable, Codable {
    let id: UUID
    let user1Id: UUID
    let user2Id: UUID
    var lastMessageAt: Date?
    var isPinnedUser1: Bool
    var isPinnedUser2: Bool
    let createdAt: Date
    
    var otherUser: User?
    var lastMessage: DMMessage?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case lastMessageAt = "last_message_at"
        case isPinnedUser1 = "is_pinned_user1"
        case isPinnedUser2 = "is_pinned_user2"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        user1Id = try container.decode(UUID.self, forKey: .user1Id)
        user2Id = try container.decode(UUID.self, forKey: .user2Id)
        isPinnedUser1 = try container.decodeIfPresent(Bool.self, forKey: .isPinnedUser1) ?? false
        isPinnedUser2 = try container.decodeIfPresent(Bool.self, forKey: .isPinnedUser2) ?? false
        
        if let dateString = try? container.decode(String.self, forKey: .lastMessageAt) {
            lastMessageAt = ISO8601DateFormatter().date(from: dateString)
        }
        
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user1Id, forKey: .user1Id)
        try container.encode(user2Id, forKey: .user2Id)
        try container.encode(isPinnedUser1, forKey: .isPinnedUser1)
        try container.encode(isPinnedUser2, forKey: .isPinnedUser2)
    }
    
    init(id: UUID = UUID(), user1Id: UUID, user2Id: UUID, lastMessageAt: Date? = nil, isPinnedUser1: Bool = false, isPinnedUser2: Bool = false, createdAt: Date = Date(), otherUser: User? = nil) {
        self.id = id
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.lastMessageAt = lastMessageAt
        self.isPinnedUser1 = isPinnedUser1
        self.isPinnedUser2 = isPinnedUser2
        self.createdAt = createdAt
        self.otherUser = otherUser
    }
}

// MARK: - DMMessage
struct DMMessage: Identifiable, Codable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let content: String
    var isRead: Bool
    let isFirstMessage: Bool
    let createdAt: Date
    
    var sender: User?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case isRead = "is_read"
        case isFirstMessage = "is_first_message"
        case createdAt = "created_at"
        case sender
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        conversationId = try container.decode(UUID.self, forKey: .conversationId)
        senderId = try container.decode(UUID.self, forKey: .senderId)
        content = try container.decode(String.self, forKey: .content)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        isFirstMessage = try container.decodeIfPresent(Bool.self, forKey: .isFirstMessage) ?? false
        sender = try container.decodeIfPresent(User.self, forKey: .sender)
        
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(conversationId, forKey: .conversationId)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(content, forKey: .content)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(isFirstMessage, forKey: .isFirstMessage)
    }
    
    init(id: UUID = UUID(), conversationId: UUID, senderId: UUID, content: String, isRead: Bool = false, isFirstMessage: Bool = false, createdAt: Date = Date(), sender: User? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.content = content
        self.isRead = isRead
        self.isFirstMessage = isFirstMessage
        self.createdAt = createdAt
        self.sender = sender
    }
}

// MARK: - AppNotification
struct AppNotification: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let actorId: UUID
    let type: String
    let postId: UUID?
    var isRead: Bool
    let createdAt: Date
    
    var actor: User?
    var post: Post?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorId = "actor_id"
        case type
        case postId = "post_id"
        case isRead = "is_read"
        case createdAt = "created_at"
        case actor
        case post
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        actorId = try container.decode(UUID.self, forKey: .actorId)
        type = try container.decode(String.self, forKey: .type)
        postId = try container.decodeIfPresent(UUID.self, forKey: .postId)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        actor = try container.decodeIfPresent(User.self, forKey: .actor)
        post = try container.decodeIfPresent(Post.self, forKey: .post)
        
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(actorId, forKey: .actorId)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(postId, forKey: .postId)
        try container.encode(isRead, forKey: .isRead)
    }
    
    init(id: UUID = UUID(), userId: UUID, actorId: UUID, type: String, postId: UUID? = nil, isRead: Bool = false, createdAt: Date = Date(), actor: User? = nil, post: Post? = nil) {
        self.id = id
        self.userId = userId
        self.actorId = actorId
        self.type = type
        self.postId = postId
        self.isRead = isRead
        self.createdAt = createdAt
        self.actor = actor
        self.post = post
    }
}

// MARK: - NotificationType
enum NotificationType: String {
    case like = "like"
    case comment = "comment"
    case reply = "reply"
    case follow = "follow"
    case dm = "dm"
    case ownerReply = "owner_reply"
    
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "bubble.right.fill"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .follow: return "person.fill.badge.plus"
        case .dm: return "envelope.fill"
        case .ownerReply: return "tag.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .like: return .pink
        case .comment: return .blue
        case .reply: return .purple
        case .follow: return .green
        case .dm: return .orange
        case .ownerReply: return .cyan
        }
    }
    
    var message: String {
        switch self {
        case .like: return "があなたの投稿にいいねしました"
        case .comment: return "がコメントしました"
        case .reply: return "が返信しました"
        case .follow: return "があなたをフォローしました"
        case .dm: return "からメッセージが届きました"
        case .ownerReply: return "が返信しました"
        }
    }
}

// MARK: - AppNotification Extension
extension AppNotification {
    var notificationType: NotificationType {
        NotificationType(rawValue: type) ?? .like
    }
}
