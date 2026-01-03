// Services/InteractionService.swift
// インタラクションサービス（いいね、コメント、フォロー、ブックマーク、通知）

import Foundation
import Supabase

class InteractionService {
    static let shared = InteractionService()
    private init() {}
    
    // =============================================
    // MARK: - いいね
    // =============================================
    
    func likePost(userId: UUID, postId: UUID) async throws {
        print("🟡 [いいね] 開始 - userId: \(userId), postId: \(postId)")
        do {
            let like = LikeInsert(user_id: userId.uuidString, post_id: postId.uuidString)
            try await SupabaseClient.shared.client
                .from("likes")
                .insert(like)
                .execute()
            
            print("✅ [いいね] 成功")
            
            // 通知を作成
            try await createNotification(postId: postId, actorId: userId, type: "like")
        } catch {
            print("🔴 [いいね] エラー: \(error)")
            throw error
        }
    }
    
    func unlikePost(userId: UUID, postId: UUID) async throws {
        print("🟡 [いいね解除] 開始 - userId: \(userId), postId: \(postId)")
        do {
            try await SupabaseClient.shared.client
                .from("likes")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("post_id", value: postId.uuidString)
                .execute()
            
            print("✅ [いいね解除] 成功")
        } catch {
            print("🔴 [いいね解除] エラー: \(error)")
            throw error
        }
    }
    
    func isLiked(userId: UUID, postId: UUID) async throws -> Bool {
        print("🟡 [いいね確認] 開始 - userId: \(userId), postId: \(postId)")
        
        struct LikeCheck: Decodable {
            let user_id: UUID
        }
        
        do {
            let response: [LikeCheck] = try await SupabaseClient.shared.client
                .from("likes")
                .select("user_id")
                .eq("user_id", value: userId.uuidString)
                .eq("post_id", value: postId.uuidString)
                .execute()
                .value
            
            let result = !response.isEmpty
            print("✅ [いいね確認] 結果: \(result)")
            return result
        } catch {
            print("🔴 [いいね確認] エラー: \(error)")
            throw error
        }
    }
    
    // =============================================
    // MARK: - コメント
    // =============================================
    
    func fetchComments(postId: UUID) async throws -> [Comment] {
        print("🟡 [コメント取得] 開始 - postId: \(postId)")
        do {
            let comments: [Comment] = try await SupabaseClient.shared.client
                .from("comments")
                .select("*, user:users(*)")
                .eq("post_id", value: postId.uuidString)
                .order("created_at", ascending: true)  // 古い順に
                .execute()
                .value
            print("✅ [コメント取得] 成功: \(comments.count)件")
            return comments
        } catch {
            print("🔴 [コメント取得] エラー: \(error)")
            throw error
        }
    }
    
    func addComment(userId: UUID, postId: UUID, content: String, parentCommentId: UUID? = nil) async throws -> Comment {
        print("🟡 [コメント投稿] 開始 - userId: \(userId), parentId: \(String(describing: parentCommentId))")
        
        struct CommentInsertWithParent: Encodable {
            let user_id: String
            let post_id: String
            let content: String
            let parent_comment_id: String?
        }
        
        do {
            let insertData = CommentInsertWithParent(
                user_id: userId.uuidString,
                post_id: postId.uuidString,
                content: content,
                parent_comment_id: parentCommentId?.uuidString
            )
            
            let comment: Comment = try await SupabaseClient.shared.client
                .from("comments")
                .insert(insertData)
                .select("*, user:users(*)")
                .single()
                .execute()
                .value
            
            print("✅ [コメント投稿] 成功")
            
            // 通知を作成（返信の場合は返信先ユーザーに、そうでなければ投稿者に）
            if let parentId = parentCommentId {
                // 返信通知（親コメントのユーザーに）
                try await createReplyNotification(parentCommentId: parentId, actorId: userId, postId: postId)
            } else {
                // 通常のコメント通知
                try await createNotification(postId: postId, actorId: userId, type: "comment")
            }
            
            return comment
        } catch {
            print("🔴 [コメント投稿] エラー: \(error)")
            throw error
        }
    }
    
    func deleteComment(commentId: UUID) async throws {
        print("🟡 [コメント削除] 開始 - commentId: \(commentId)")
        do {
            // 返信も一緒に削除される（CASCADE）
            try await SupabaseClient.shared.client
                .from("comments")
                .delete()
                .eq("id", value: commentId.uuidString)
                .execute()
            print("✅ [コメント削除] 成功")
        } catch {
            print("🔴 [コメント削除] エラー: \(error)")
            throw error
        }
    }
    
    // =============================================
    // MARK: - フォロー
    // =============================================
    
    func follow(followerId: UUID, followingId: UUID) async throws {
        print("🟡 [フォロー] 開始 - follower: \(followerId), following: \(followingId)")
        do {
            let follow = FollowInsert(follower_id: followerId.uuidString, following_id: followingId.uuidString)
            try await SupabaseClient.shared.client
                .from("follows")
                .insert(follow)
                .execute()
            
            print("✅ [フォロー] 成功")
            
            // 直接通知を作成
            try await createNotificationDirect(userId: followingId, actorId: followerId, type: "follow")
        } catch {
            print("🔴 [フォロー] エラー: \(error)")
            throw error
        }
    }
    
    func unfollow(followerId: UUID, followingId: UUID) async throws {
        print("🟡 [フォロー解除] 開始 - follower: \(followerId), following: \(followingId)")
        do {
            try await SupabaseClient.shared.client
                .from("follows")
                .delete()
                .eq("follower_id", value: followerId.uuidString)
                .eq("following_id", value: followingId.uuidString)
                .execute()
            print("✅ [フォロー解除] 成功")
        } catch {
            print("🔴 [フォロー解除] エラー: \(error)")
            throw error
        }
    }
    
    func isFollowing(followerId: UUID, followingId: UUID) async throws -> Bool {
        print("🟡 [フォロー確認] 開始 - follower: \(followerId), following: \(followingId)")
        
        struct FollowCheck: Decodable {
            let follower_id: UUID
        }
        
        do {
            let response: [FollowCheck] = try await SupabaseClient.shared.client
                .from("follows")
                .select("follower_id")
                .eq("follower_id", value: followerId.uuidString)
                .eq("following_id", value: followingId.uuidString)
                .execute()
                .value
            
            let result = !response.isEmpty
            print("✅ [フォロー確認] 結果: \(result)")
            return result
        } catch {
            print("🔴 [フォロー確認] エラー: \(error)")
            throw error
        }
    }

    func getFollowCounts(userId: UUID) async throws -> (followers: Int, following: Int) {
        struct FollowCountCheck: Decodable { let id: UUID? }
        
        let followers: [FollowCountCheck] = try await SupabaseClient.shared.client
            .from("follows")
            .select("follower_id") // IDがない可能性を考慮
            .eq("following_id", value: userId.uuidString)
            .execute()
            .value
        
        let following: [FollowCountCheck] = try await SupabaseClient.shared.client
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userId.uuidString)
            .execute()
            .value
        
        return (followers.count, following.count)
    }
    
    // MARK: - いいねしたユーザー一覧取得
    // MARK: - いいねしたユーザー一覧取得（自分を除外）
    func fetchLikedUsers(postId: UUID, excludeUserId: UUID? = nil) async throws -> [User] {
        print("🟡 [いいねユーザー] 開始 - postId: \(postId)")
        
        struct LikeWithUser: Decodable {
            let user: User
        }
        
        do {
            let likes: [LikeWithUser] = try await SupabaseClient.shared.client
                .from("likes")
                .select("user:users(*)")
                .eq("post_id", value: postId.uuidString)
                .execute()
                .value
            
            var users = likes.map { $0.user }
            
            if let excludeId = excludeUserId {
                users = users.filter { $0.id != excludeId }
            }
            
            print("✅ [いいねユーザー] 成功 - 件数: \(users.count)")
            return users
        } catch {
            print("🔴 [いいねユーザー] エラー: \(error)")
            throw error
        }
    }
    
    // =============================================
    // MARK: - ブックマーク
    // =============================================
    
    func bookmarkPost(userId: UUID, postId: UUID) async throws {
        print("🟡 [ブックマーク] 開始 - userId: \(userId), postId: \(postId)")
        do {
            let bookmark = BookmarkInsert(user_id: userId.uuidString, post_id: postId.uuidString)
            try await SupabaseClient.shared.client
                .from("bookmarks")
                .insert(bookmark)
                .execute()
            print("✅ [ブックマーク] 成功")
        } catch {
            print("🔴 [ブックマーク] エラー: \(error)")
            throw error
        }
    }
    
    func unbookmarkPost(userId: UUID, postId: UUID) async throws {
        print("🟡 [ブックマーク解除] 開始 - userId: \(userId), postId: \(postId)")
        do {
            try await SupabaseClient.shared.client
                .from("bookmarks")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("post_id", value: postId.uuidString)
                .execute()
            print("✅ [ブックマーク解除] 成功")
        } catch {
            print("🔴 [ブックマーク解除] エラー: \(error)")
            throw error
        }
    }
    
    func isBookmarked(userId: UUID, postId: UUID) async throws -> Bool {
        print("🟡 [ブックマーク確認] 開始 - userId: \(userId), postId: \(postId)")
        
        struct BookmarkCheck: Decodable {
            let user_id: UUID
        }
        
        do {
            let response: [BookmarkCheck] = try await SupabaseClient.shared.client
                .from("bookmarks")
                .select("user_id")
                .eq("user_id", value: userId.uuidString)
                .eq("post_id", value: postId.uuidString)
                .execute()
                .value
            
            let result = !response.isEmpty
            print("✅ [ブックマーク確認] 結果: \(result)")
            return result
        } catch {
            print("🔴 [ブックマーク確認] エラー: \(error)")
            throw error
        }
    }
    // MARK: - ブックマーク取得
    func fetchBookmarks(userId: UUID) async throws -> [Post] {
        print("🟡 [ブックマーク取得] 開始 - userId: \(userId)")
        
        // 専用のデコード構造体
        struct BookmarkWithPost: Decodable {
            let post: Post
        }
        
        do {
            let bookmarks: [BookmarkWithPost] = try await SupabaseClient.shared.client
                .from("bookmarks")
                .select("""
                    post:posts(
                        *,
                        user:users(*),
                        nodes(*),
                        connections:node_connections(*)
                    )
                """)
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let posts = bookmarks.compactMap { $0.post }
            print("✅ [ブックマーク取得] 成功 - 件数: \(posts.count)")
            return posts
        } catch {
            print("🔴 [ブックマーク取得] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - フォロワー一覧取得
    func fetchFollowers(userId: UUID) async throws -> [User] {
        print("🟡 [フォロワー一覧] 開始 - userId: \(userId)")
        
        struct FollowWithUser: Decodable {
            let follower: User
        }
        
        do {
            let follows: [FollowWithUser] = try await SupabaseClient.shared.client
                .from("follows")
                .select("follower:users!follower_id(*)")
                .eq("following_id", value: userId.uuidString)
                .execute()
                .value
            
            let users = follows.map { $0.follower }
            print("✅ [フォロワー一覧] 成功 - 件数: \(users.count)")
            return users
        } catch {
            print("🔴 [フォロワー一覧] エラー: \(error)")
            throw error
        }
    }

    // MARK: - フォロー中一覧取得
    func fetchFollowing(userId: UUID) async throws -> [User] {
        print("🟡 [フォロー中一覧] 開始 - userId: \(userId)")
        
        struct FollowWithUser: Decodable {
            let following: User
        }
        
        do {
            let follows: [FollowWithUser] = try await SupabaseClient.shared.client
                .from("follows")
                .select("following:users!following_id(*)")
                .eq("follower_id", value: userId.uuidString)
                .execute()
                .value
            
            let users = follows.map { $0.following }
            print("✅ [フォロー中一覧] 成功 - 件数: \(users.count)")
            return users
        } catch {
            print("🔴 [フォロー中一覧] エラー: \(error)")
            throw error
        }
    }
    
    // =============================================
    // MARK: - 通知ヘルパー
    // =============================================
    
    private func createNotification(postId: UUID, actorId: UUID, type: String) async throws {
        print("🟡 [通知準備] 投稿オーナー取得中 - postId: \(postId)")
        
        // user_idだけ取得するための専用構造体
        struct PostOwner: Decodable {
            let user_id: UUID
        }
        
        let postOwner: PostOwner = try await SupabaseClient.shared.client
            .from("posts")
            .select("user_id")
            .eq("id", value: postId.uuidString)
            .single()
            .execute()
            .value
        
        guard postOwner.user_id != actorId else {
            print("ℹ️ [通知] 自分自身の行動のため通知をスキップ")
            return
        }
        
        try await createNotificationDirect(userId: postOwner.user_id, actorId: actorId, type: type, postId: postId)
    }
    
    // 返信通知を作成
    private func createReplyNotification(parentCommentId: UUID, actorId: UUID, postId: UUID) async throws {
        print("🟡 [返信通知] 開始")
        
        struct CommentOwner: Decodable {
            let user_id: UUID
        }
        
        do {
            let parentComment: CommentOwner = try await SupabaseClient.shared.client
                .from("comments")
                .select("user_id")
                .eq("id", value: parentCommentId.uuidString)
                .single()
                .execute()
                .value
            
            // 自分自身への返信は通知しない
            guard parentComment.user_id != actorId else {
                print("ℹ️ [返信通知] 自分への返信のためスキップ")
                return
            }
            
            try await createNotificationDirect(userId: parentComment.user_id, actorId: actorId, type: "reply", postId: postId)
            print("✅ [返信通知] 成功")
        } catch {
            print("🔴 [返信通知] エラー: \(error)")
        }
    }
    
    private func createNotificationDirect(userId: UUID, actorId: UUID, type: String, postId: UUID? = nil) async throws {
        print("🟡 [通知作成] 開始 - targetUserId: \(userId), type: \(type)")
        do {
            let notification = NotificationInsert(
                user_id: userId.uuidString,
                actor_id: actorId.uuidString,
                type: type,
                post_id: postId?.uuidString
            )
            try await SupabaseClient.shared.client
                .from("notifications")
                .insert(notification)
                .execute()
            print("✅ [通知作成] 成功")
        } catch {
            print("🔴 [通知作成] エラー: \(error)")
        }
    }
}

// =============================================
// MARK: - 内部用構造体
// =============================================

private struct LikeInsert: Encodable { let user_id: String; let post_id: String }
private struct BookmarkInsert: Encodable { let user_id: String; let post_id: String }
private struct FollowInsert: Encodable { let follower_id: String; let following_id: String }
private struct CommentInsert: Encodable { let user_id: String; let post_id: String; let content: String }
private struct NotificationInsert: Encodable { let user_id: String; let actor_id: String; let type: String; let post_id: String? }
