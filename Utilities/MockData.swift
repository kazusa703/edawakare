// Utilities/MockData.swift
// モックデータ（Supabase連携後は使用されませんが、プレビュー用に保持）

import Foundation

struct MockData {
    // サンプルユーザー
    static let sampleUser = User(
        id: UUID(),
        email: "sample@example.com",
        username: "sample_user",
        displayName: "サンプルユーザー",
        bio: "これはサンプルのユーザーです",
        avatarUrl: nil,
        totalBranches: 42,
        isPrivate: false,
        dmPermission: "everyone"
    )
    
    static let sampleUser2 = User(
        id: UUID(),
        email: "user2@example.com",
        username: "user_two",
        displayName: "ユーザー2",
        bio: nil,
        avatarUrl: nil,
        totalBranches: 10,
        isPrivate: false,
        dmPermission: "everyone"
    )
    
    // サンプル投稿
    static var samplePost: Post {
        let postId = UUID()
        let centerNodeId = UUID()
        let node1Id = UUID()
        let node2Id = UUID()
        
        let nodes = [
            Node(id: centerNodeId, postId: postId, text: "進撃の巨人", positionX: 200, positionY: 300, isCenter: true),
            Node(id: node1Id, postId: postId, text: "エレン", positionX: 100, positionY: 200, isCenter: false),
            Node(id: node2Id, postId: postId, text: "ミカサ", positionX: 300, positionY: 200, isCenter: false)
        ]
        
        let connections = [
            NodeConnection(id: UUID(), postId: postId, fromNodeId: centerNodeId, toNodeId: node1Id, reason: "主人公"),
            NodeConnection(id: UUID(), postId: postId, fromNodeId: centerNodeId, toNodeId: node2Id, reason: "ヒロイン")
        ]
        
        return Post(
            id: postId,
            userId: sampleUser.id,
            centerNodeText: "進撃の巨人",
            likeCount: 42,
            commentCount: 5,
            isDeleted: false,
            createdAt: Date(),
            updatedAt: Date(),
            user: sampleUser,
            nodes: nodes,
            connections: connections
        )
    }
    
    // サンプル投稿リスト
    static var samplePosts: [Post] {
        [samplePost]
    }
    
    // サンプルコメント
    static var sampleComments: [Comment] {
        [
            Comment(
                id: UUID(),
                userId: sampleUser2.id,
                postId: samplePost.id,
                content: "すごく共感します！",
                createdAt: Date().addingTimeInterval(-3600),
                user: sampleUser2
            ),
            Comment(
                id: UUID(),
                userId: sampleUser.id,
                postId: samplePost.id,
                content: "ありがとうございます！",
                createdAt: Date().addingTimeInterval(-1800),
                user: sampleUser
            )
        ]
    }
    
    // サンプル通知
    static var sampleNotifications: [AppNotification] {
        [
            AppNotification(
                id: UUID(),
                userId: sampleUser.id,
                actorId: sampleUser2.id,
                type: "like",
                postId: samplePost.id,
                isRead: false,
                createdAt: Date().addingTimeInterval(-3600),
                actor: sampleUser2,
                post: samplePost
            ),
            AppNotification(
                id: UUID(),
                userId: sampleUser.id,
                actorId: sampleUser2.id,
                type: "follow",
                postId: nil,
                isRead: true,
                createdAt: Date().addingTimeInterval(-7200),
                actor: sampleUser2,
                post: nil
            )
        ]
    }
    
    // サンプル会話
    static var sampleConversations: [Conversation] {
        [
            Conversation(
                id: UUID(),
                user1Id: sampleUser.id,
                user2Id: sampleUser2.id,
                lastMessageAt: Date(),
                isPinnedUser1: false,
                isPinnedUser2: false,
                createdAt: Date().addingTimeInterval(-86400),
                otherUser: sampleUser2
            )
        ]
    }
    
    // サンプルメッセージ
    static var sampleMessages: [DMMessage] {
        let convId = UUID()
        return [
            DMMessage(
                id: UUID(),
                conversationId: convId,
                senderId: sampleUser2.id,
                content: "こんにちは！",
                isRead: true,
                isFirstMessage: true,
                createdAt: Date().addingTimeInterval(-3600),
                sender: sampleUser2
            ),
            DMMessage(
                id: UUID(),
                conversationId: convId,
                senderId: sampleUser.id,
                content: "こんにちは！よろしくお願いします。",
                isRead: true,
                isFirstMessage: false,
                createdAt: Date().addingTimeInterval(-1800),
                sender: sampleUser
            )
        ]
    }
}
