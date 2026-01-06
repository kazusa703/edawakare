// Services/PostService.swift
// 投稿サービス（Supabase連携版）

import Foundation
import Supabase

// MARK: - 入力用の構造体
struct NodeInput {
    let localId: String
    let text: String
    let positionX: Double
    let positionY: Double
    let isCenter: Bool
    var note: String?
    var style: String?
    var edition: Int = 1  // 追加
}

struct ConnectionInput {
    let fromLocalId: String
    let toLocalId: String
    let reason: String?
    var style: String?
}

class PostService {
    static let shared = PostService()
    
    private init() {}
    
    // MARK: - 投稿一覧取得（おすすめ）- 公開範囲フィルタリング対応
    func fetchPosts(limit: Int = 50, excludeUserId: UUID? = nil, currentUserId: UUID? = nil) async throws -> [Post] {
        print("🟡 [投稿一覧] 開始 - limit: \(limit)")

        do {
            var query = SupabaseClient.shared.client
                .from("posts")
                .select("""
                    *,
                    user:users(*),
                    nodes(*),
                    connections:node_connections(*)
                """)
                .eq("is_deleted", value: false)
                .eq("visibility", value: "public")  // publicのみ表示

            if let excludeId = excludeUserId {
                query = query.neq("user_id", value: excludeId.uuidString)
            }

            let posts: [Post] = try await query
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            print("✅ [投稿一覧] 成功 - 件数: \(posts.count)")
            return posts
        } catch {
            print("🔴 [投稿一覧] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - フォロー中の投稿取得 - 公開範囲フィルタリング対応
    func fetchFollowingPosts(userId: UUID, limit: Int = 50) async throws -> [Post] {
        print("🟡 [フォロー中投稿] 開始 - userId: \(userId)")

        struct FollowingId: Decodable {
            let following_id: UUID
        }

        do {
            let follows: [FollowingId] = try await SupabaseClient.shared.client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: userId.uuidString)
                .execute()
                .value

            let followingIds = follows.map { $0.following_id.uuidString }
            print("🟡 [フォロー中投稿] フォロー中: \(followingIds.count)人")

            guard !followingIds.isEmpty else {
                print("✅ [フォロー中投稿] フォロー中のユーザーなし")
                return []
            }

            // フォロワーにはpublicとfollowersの投稿を表示
            let posts: [Post] = try await SupabaseClient.shared.client
                .from("posts")
                .select("""
                    *,
                    user:users(*),
                    nodes(*),
                    connections:node_connections(*)
                """)
                .eq("is_deleted", value: false)
                .in("user_id", values: followingIds)
                .or("visibility.eq.public,visibility.eq.followers")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            print("✅ [フォロー中投稿] 成功 - 件数: \(posts.count)")
            return posts
        } catch {
            print("🔴 [フォロー中投稿] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - ユーザーの投稿取得
    func fetchUserPosts(userId: UUID, limit: Int = 50) async throws -> [Post] {
        print("🟡 [ユーザー投稿] 開始 - userId: \(userId)")
        
        do {
            let posts: [Post] = try await SupabaseClient.shared.client
                .from("posts")
                .select("""
                    *,
                    user:users(*),
                    nodes(*),
                    connections:node_connections(*)
                """)
                .eq("user_id", value: userId.uuidString)
                .eq("is_deleted", value: false)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            print("✅ [ユーザー投稿] 成功 - 件数: \(posts.count)")
            return posts
        } catch {
            print("🔴 [ユーザー投稿] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 投稿詳細取得
    func fetchPostDetail(postId: UUID) async throws -> Post {
        print("🟡 [投稿詳細] 開始 - postId: \(postId)")
        
        do {
            let post: Post = try await SupabaseClient.shared.client
                .from("posts")
                .select("""
                    *,
                    user:users(*),
                    nodes(*),
                    connections:node_connections(*)
                """)
                .eq("id", value: postId.uuidString)
                .single()
                .execute()
                .value
            
            print("✅ [投稿詳細] 成功")
            return post
        } catch {
            print("🔴 [投稿詳細] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 投稿作成
    func createPost(
        userId: UUID,
        centerNodeText: String,
        nodes: [NodeInput],
        connections: [ConnectionInput],
        visibility: String = "public",
        commentsEnabled: Bool = true,
        allowSave: Bool = true,
        displayScale: Double = 1.0,
        displayOffsetX: Double = 0,
        displayOffsetY: Double = 0
    ) async throws -> Post {
        print("🟡 [投稿作成] 開始")

        struct PostInsert: Encodable {
            let user_id: String
            let center_node_text: String
            let visibility: String
            let comments_enabled: Bool
            let allow_save: Bool
            let current_edition: Int
            let display_scale: Double
            let display_offset_x: Double
            let display_offset_y: Double
        }
        
        struct NodeInsert: Encodable {
            let post_id: String
            let text: String
            let position_x: Double
            let position_y: Double
            let is_center: Bool
            let note: String?
            let style: String?
            let edition: Int
        }
        
        struct ConnectionInsert: Encodable {
            let post_id: String
            let from_node_id: String
            let to_node_id: String
            let reason: String?
            let style: String?
        }
        
        do {
            // 1. 投稿を作成（edition = 1 で開始）
            let postInsert = PostInsert(
                user_id: userId.uuidString,
                center_node_text: centerNodeText,
                visibility: visibility,
                comments_enabled: commentsEnabled,
                allow_save: allowSave,
                current_edition: 1,
                display_scale: displayScale,
                display_offset_x: displayOffsetX,
                display_offset_y: displayOffsetY
            )
            
            let post: Post = try await SupabaseClient.shared.client
                .from("posts")
                .insert(postInsert)
                .select()
                .single()
                .execute()
                .value
            
            print("🟡 [投稿作成] 投稿ID: \(post.id)")
            
            // 2. ノードを作成（全て edition = 1）
            var localIdToUUID: [String: UUID] = [:]
            
            for nodeInput in nodes {
                let nodeInsert = NodeInsert(
                    post_id: post.id.uuidString,
                    text: nodeInput.text,
                    position_x: nodeInput.positionX,
                    position_y: nodeInput.positionY,
                    is_center: nodeInput.isCenter,
                    note: nodeInput.note,
                    style: nodeInput.style,
                    edition: 1  // 初回投稿は全て edition = 1
                )
                
                let node: Node = try await SupabaseClient.shared.client
                    .from("nodes")
                    .insert(nodeInsert)
                    .select()
                    .single()
                    .execute()
                    .value
                
                localIdToUUID[nodeInput.localId] = node.id
            }
            
            // 3. コネクションを作成
            for connInput in connections {
                guard let fromId = localIdToUUID[connInput.fromLocalId],
                      let toId = localIdToUUID[connInput.toLocalId] else { continue }
                
                let connInsert = ConnectionInsert(
                    post_id: post.id.uuidString,
                    from_node_id: fromId.uuidString,
                    to_node_id: toId.uuidString,
                    reason: connInput.reason,
                    style: connInput.style
                )
                
                try await SupabaseClient.shared.client
                    .from("node_connections")
                    .insert(connInsert)
                    .execute()
            }
            
            // 4. 完成した投稿を再取得
            let completePost = try await fetchPostDetail(postId: post.id)
            print("✅ [投稿作成] 成功")
            return completePost
            
        } catch {
            print("🔴 [投稿作成] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 人気のテーマ取得
    func fetchPopularThemes(limit: Int = 10) async throws -> [String] {
        print("🟡 [人気ノード] 開始")
        
        struct PopularPost: Decodable {
            let center_node_text: String
        }
        
        do {
            let posts: [PopularPost] = try await SupabaseClient.shared.client
                .from("posts")
                .select("center_node_text")
                .eq("is_deleted", value: false)
                .order("like_count", ascending: false)
                .limit(limit * 3)
                .execute()
                .value
            
            var seen = Set<String>()
            let uniqueNodes = posts.compactMap { post -> String? in
                let text = post.center_node_text
                if seen.contains(text) { return nil }
                seen.insert(text)
                return text
            }
            
            print("✅ [人気ノード] 成功 - 件数: \(uniqueNodes.count)")
            return uniqueNodes
        } catch {
            print("🔴 [人気ノード] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 投稿削除（論理削除）
    func deletePost(postId: UUID) async throws {
        print("🟡 [投稿削除] 開始 - postId: \(postId)")
        
        do {
            try await SupabaseClient.shared.client
                .from("posts")
                .update(["is_deleted": true])
                .eq("id", value: postId.uuidString)
                .execute()
            
            print("✅ [投稿削除] 成功")
        } catch {
            print("🔴 [投稿削除] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 投稿更新
    func updatePost(postId: UUID, isPinned: Bool? = nil, visibility: String? = nil, commentsEnabled: Bool? = nil, allowSave: Bool? = nil) async throws {
        print("🟡 [投稿更新] 開始 - postId: \(postId)")
        
        do {
            if let isPinned = isPinned {
                try await SupabaseClient.shared.client
                    .from("posts")
                    .update(["is_pinned": isPinned])
                    .eq("id", value: postId.uuidString)
                    .execute()
            }
            
            if let visibility = visibility {
                try await SupabaseClient.shared.client
                    .from("posts")
                    .update(["visibility": visibility])
                    .eq("id", value: postId.uuidString)
                    .execute()
            }
            
            if let commentsEnabled = commentsEnabled {
                try await SupabaseClient.shared.client
                    .from("posts")
                    .update(["comments_enabled": commentsEnabled])
                    .eq("id", value: postId.uuidString)
                    .execute()
            }

            if let allowSave = allowSave {
                try await SupabaseClient.shared.client
                    .from("posts")
                    .update(["allow_save": allowSave])
                    .eq("id", value: postId.uuidString)
                    .execute()
            }

            print("✅ [投稿更新] 成功")
        } catch {
            print("🔴 [投稿更新] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - ノード追加（Edition対応）
    func addNode(postId: UUID, text: String, positionX: Double, positionY: Double, isCenter: Bool, edition: Int = 1, note: String? = nil, style: String? = nil) async throws -> Node {
        print("🟡 [ノード追加] 開始 - postId: \(postId), text: \(text), edition: \(edition)")
        
        struct NodeInsert: Encodable {
            let post_id: String
            let text: String
            let position_x: Double
            let position_y: Double
            let is_center: Bool
            let edition: Int
            let note: String?
            let style: String?
        }
        
        do {
            let nodeInsert = NodeInsert(
                post_id: postId.uuidString,
                text: text,
                position_x: positionX,
                position_y: positionY,
                is_center: isCenter,
                edition: edition,
                note: note,
                style: style
            )
            
            let node: Node = try await SupabaseClient.shared.client
                .from("nodes")
                .insert(nodeInsert)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ [ノード追加] 成功 - nodeId: \(node.id)")
            return node
        } catch {
            print("🔴 [ノード追加] エラー: \(error)")
            throw error
        }
    }

    // MARK: - コネクション追加
    func addConnection(postId: UUID, fromNodeId: UUID, toNodeId: UUID, reason: String?, style: String? = nil) async throws {
        print("🟡 [コネクション追加] 開始")
        
        struct ConnectionInsert: Encodable {
            let post_id: String
            let from_node_id: String
            let to_node_id: String
            let reason: String?
            let style: String?
        }
        
        do {
            let insert = ConnectionInsert(
                post_id: postId.uuidString,
                from_node_id: fromNodeId.uuidString,
                to_node_id: toNodeId.uuidString,
                reason: reason,
                style: style
            )
            
            try await SupabaseClient.shared.client
                .from("node_connections")
                .insert(insert)
                .execute()
            
            print("✅ [コネクション追加] 成功")
        } catch {
            print("🔴 [コネクション追加] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - Edition更新（編集完了時にインクリメント）
    func incrementEdition(postId: UUID) async throws {
        print("🟡 [Edition更新] 開始 - postId: \(postId)")
        
        do {
            // 現在のeditionを取得
            let post = try await fetchPostDetail(postId: postId)
            let newEdition = post.currentEdition + 1
            
            try await SupabaseClient.shared.client
                .from("posts")
                .update(["current_edition": newEdition])
                .eq("id", value: postId.uuidString)
                .execute()
            
            print("✅ [Edition更新] 成功 - newEdition: \(newEdition)")
        } catch {
            print("🔴 [Edition更新] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - フィード表示設定更新
    func updateDisplaySettings(postId: UUID, scale: Double, offsetX: Double, offsetY: Double) async throws {
        print("🟡 [表示設定更新] 開始 - postId: \(postId)")

        do {
            try await SupabaseClient.shared.client
                .from("posts")
                .update([
                    "display_scale": scale,
                    "display_offset_x": offsetX,
                    "display_offset_y": offsetY
                ])
                .eq("id", value: postId.uuidString)
                .execute()

            print("✅ [表示設定更新] 成功")
        } catch {
            print("🔴 [表示設定更新] エラー: \(error)")
            throw error
        }
    }

    // MARK: - ノードテキストで検索 - 公開範囲フィルタリング対応
    func searchByNodeText(query: String) async throws -> [Post] {
        print("🟡 [投稿検索] 開始 - query: \(query)")

        do {
            let posts: [Post] = try await SupabaseClient.shared.client
                .from("posts")
                .select("""
                    *,
                    user:users(*),
                    nodes(*),
                    connections:node_connections(*)
                """)
                .ilike("center_node_text", pattern: "%\(query)%")
                .eq("is_deleted", value: false)
                .eq("visibility", value: "public")  // 検索結果はpublicのみ
                .order("created_at", ascending: false)
                .limit(30)
                .execute()
                .value

            print("✅ [投稿検索] 成功 - 件数: \(posts.count)")
            return posts
        } catch {
            print("🔴 [投稿検索] エラー: \(error)")
            throw error
        }
    }

    // MARK: - 投稿更新（hideLikeCount追加）
    func updateHideLikeCount(postId: UUID, hideLikeCount: Bool) async throws {
        print("🟡 [いいね数非表示更新] 開始 - postId: \(postId)")

        do {
            try await SupabaseClient.shared.client
                .from("posts")
                .update(["hide_like_count": hideLikeCount])
                .eq("id", value: postId.uuidString)
                .execute()

            print("✅ [いいね数非表示更新] 成功")
        } catch {
            print("🔴 [いいね数非表示更新] エラー: \(error)")
            throw error
        }
    }
}
