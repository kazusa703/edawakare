// Services/CommentService.swift

import Foundation
import Supabase

class CommentService {
    static let shared = CommentService()
    private init() {}

    // =============================================
    // MARK: - コメント取得（ソート対応）
    // =============================================

    /// コメント取得（ソート対応）
    /// - Parameters:
    ///   - postId: 投稿ID
    ///   - sortBy: "recent"（新着順）または "popular"（人気順）
    func fetchComments(postId: UUID, sortBy: String = "recent") async throws -> [Comment] {
        print("🟡 [コメント取得] 開始 - postId: \(postId), sortBy: \(sortBy)")

        do {
            let comments: [Comment]

            if sortBy == "popular" {
                // 人気順：いいね数降順
                comments = try await SupabaseClient.shared.client
                    .from("comments")
                    .select("*, user:users(*)")
                    .eq("post_id", value: postId.uuidString)
                    .order("like_count", ascending: false)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            } else {
                // 新着順（デフォルト）
                comments = try await SupabaseClient.shared.client
                    .from("comments")
                    .select("*, user:users(*)")
                    .eq("post_id", value: postId.uuidString)
                    .order("created_at", ascending: true)
                    .execute()
                    .value
            }

            print("✅ [コメント取得] 成功: \(comments.count)件")
            return comments
        } catch {
            print("🔴 [コメント取得] エラー: \(error)")
            throw error
        }
    }

    // =============================================
    // MARK: - 返信作成
    // =============================================

    /// 返信コメントを作成
    func replyToComment(postId: UUID, parentId: UUID, userId: UUID, content: String) async throws -> Comment {
        print("🟡 [返信作成] 開始 - postId: \(postId), parentId: \(parentId)")

        struct CommentInsertWithParent: Encodable {
            let user_id: String
            let post_id: String
            let content: String
            let parent_comment_id: String
        }

        do {
            let insertData = CommentInsertWithParent(
                user_id: userId.uuidString,
                post_id: postId.uuidString,
                content: content,
                parent_comment_id: parentId.uuidString
            )

            let comment: Comment = try await SupabaseClient.shared.client
                .from("comments")
                .insert(insertData)
                .select("*, user:users(*)")
                .single()
                .execute()
                .value

            print("✅ [返信作成] 成功")

            // 返信通知を送信
            try await createReplyNotification(parentCommentId: parentId, actorId: userId, postId: postId)

            return comment
        } catch {
            print("🔴 [返信作成] エラー: \(error)")
            throw error
        }
    }

    // =============================================
    // MARK: - コメントいいね
    // =============================================

    /// コメントにいいね
    func likeComment(commentId: UUID, userId: UUID) async throws {
        print("🟡 [コメントいいね] 開始 - commentId: \(commentId), userId: \(userId)")

        struct CommentLikeInsert: Encodable {
            let comment_id: String
            let user_id: String
        }

        do {
            let like = CommentLikeInsert(
                comment_id: commentId.uuidString,
                user_id: userId.uuidString
            )

            try await SupabaseClient.shared.client
                .from("comment_likes")
                .insert(like)
                .execute()

            // like_count をインクリメント
            try await SupabaseClient.shared.client
                .rpc("increment_comment_like_count", params: ["comment_id_param": commentId.uuidString])
                .execute()

            print("✅ [コメントいいね] 成功")
        } catch {
            print("🔴 [コメントいいね] エラー: \(error)")
            throw error
        }
    }

    /// コメントいいね解除
    func unlikeComment(commentId: UUID, userId: UUID) async throws {
        print("🟡 [コメントいいね解除] 開始 - commentId: \(commentId), userId: \(userId)")

        do {
            try await SupabaseClient.shared.client
                .from("comment_likes")
                .delete()
                .eq("comment_id", value: commentId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            // like_count をデクリメント
            try await SupabaseClient.shared.client
                .rpc("decrement_comment_like_count", params: ["comment_id_param": commentId.uuidString])
                .execute()

            print("✅ [コメントいいね解除] 成功")
        } catch {
            print("🔴 [コメントいいね解除] エラー: \(error)")
            throw error
        }
    }

    /// コメントいいね確認
    func isCommentLiked(commentId: UUID, userId: UUID) async throws -> Bool {
        print("🟡 [コメントいいね確認] 開始 - commentId: \(commentId), userId: \(userId)")

        struct CommentLikeCheck: Decodable {
            let id: UUID
        }

        do {
            let response: [CommentLikeCheck] = try await SupabaseClient.shared.client
                .from("comment_likes")
                .select("id")
                .eq("comment_id", value: commentId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let result = !response.isEmpty
            print("✅ [コメントいいね確認] 結果: \(result)")
            return result
        } catch {
            print("🔴 [コメントいいね確認] エラー: \(error)")
            throw error
        }
    }

    // =============================================
    // MARK: - 通知ヘルパー
    // =============================================

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

            struct NotificationInsert: Encodable {
                let user_id: String
                let actor_id: String
                let type: String
                let post_id: String?
            }

            let notification = NotificationInsert(
                user_id: parentComment.user_id.uuidString,
                actor_id: actorId.uuidString,
                type: "reply",
                post_id: postId.uuidString
            )

            try await SupabaseClient.shared.client
                .from("notifications")
                .insert(notification)
                .execute()

            print("✅ [返信通知] 成功")
        } catch {
            print("🔴 [返信通知] エラー: \(error)")
        }
    }
}
