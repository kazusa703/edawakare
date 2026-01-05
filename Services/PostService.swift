// Services/PostService.swift
// 投稿サービス（Supabase連携版）

import Foundation
import Supabase

// MARK: - 入力用の構造体（トップレベルに移動）
struct NodeInput {
    let localId: String
    let text: String
    let positionX: Double
    let positionY: Double
    let isCenter: Bool
    var note: String?
    var style: String?  // 追加
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
    
    // MARK: - 投稿一覧取得（おすすめ）- 自分の投稿を除外
    func fetchPosts(limit: Int = 50, excludeUserId: UUID? = nil) async throws -> [Post] {
        print("🟡 [投稿一覧] 開始 - limit: \(limit), excludeUserId: \(String(describing: excludeUserId))")
        
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
    
    // MARK: - フォロー中の投稿取得
    /// MARK: - フォロー中の投稿取得
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
    func fetchUserPosts(userId: UUID) async throws -> [Post] {
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
    func fetchPost(postId: UUID) async throws -> Post {
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
            
            print("✅ [投稿詳細] 成功 - centerNodeText: \(post.centerNodeText)")
            return post
        } catch {
            print("🔴 [投稿詳細] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 投稿作成
    func createPost(userId: UUID, centerNodeText: String, nodes: [NodeInput], connections: [ConnectionInput]) async throws -> Post {
        print("🟡 [投稿作成] 開始 - userId: \(userId), centerNodeText: \(centerNodeText)")
        print("🟡 [投稿作成] ノード数: \(nodes.count), コネクション数: \(connections.count)")
        
        do {
            // 1. 投稿を作成
            struct PostInsert: Encodable {
                let user_id: String
                let center_node_text: String
            }
            
            let postInsert = PostInsert(user_id: userId.uuidString, center_node_text: centerNodeText)
            
            print("🟡 [投稿作成] 投稿レコード作成中...")
            let createdPost: Post = try await SupabaseClient.shared.client
                .from("posts")
                .insert(postInsert)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ [投稿作成] 投稿レコード作成成功 - postId: \(createdPost.id)")
            
            // 2. ノードを作成
            var nodeIdMap: [String: UUID] = [:]
            
            for node in nodes {
                struct NodeInsert: Encodable {
                    let post_id: String
                    let text: String
                    let position_x: Double
                    let position_y: Double
                    let is_center: Bool
                }
                
                let nodeInsert = NodeInsert(
                    post_id: createdPost.id.uuidString,
                    text: node.text,
                    position_x: node.positionX,
                    position_y: node.positionY,
                    is_center: node.isCenter
                )
                
                print("🟡 [投稿作成] ノード作成中 - text: \(node.text), isCenter: \(node.isCenter)")
                let createdNode: Node = try await SupabaseClient.shared.client
                    .from("nodes")
                    .insert(nodeInsert)
                    .select()
                    .single()
                    .execute()
                    .value
                
                nodeIdMap[node.localId] = createdNode.id
                print("✅ [投稿作成] ノード作成成功 - nodeId: \(createdNode.id)")
            }
            
            // 3. コネクションを作成
            for connection in connections {
                guard let fromId = nodeIdMap[connection.fromLocalId],
                      let toId = nodeIdMap[connection.toLocalId] else {
                    print("🔴 [投稿作成] コネクション作成スキップ - ノードが見つからない")
                    continue
                }
                
                struct ConnectionInsert: Encodable {
                    let post_id: String
                    let from_node_id: String
                    let to_node_id: String
                    let reason: String?
                }
                
                let connectionInsert = ConnectionInsert(
                    post_id: createdPost.id.uuidString,
                    from_node_id: fromId.uuidString,
                    to_node_id: toId.uuidString,
                    reason: connection.reason
                )
                
                print("🟡 [投稿作成] コネクション作成中 - from: \(fromId), to: \(toId)")
                try await SupabaseClient.shared.client
                    .from("node_connections")
                    .insert(connectionInsert)
                    .execute()
                
                print("✅ [投稿作成] コネクション作成成功")
            }
            
            // 4. 完成した投稿を取得して返す
            print("🟡 [投稿作成] 完成した投稿を取得中...")
            let finalPost = try await fetchPost(postId: createdPost.id)
            print("✅ [投稿作成] 完了")
            return finalPost
        } catch {
            print("🔴 [投稿作成] エラー: \(error)")
            throw error
        }
    }
    // MARK: - 保存許可設定を更新
    func updateAllowSave(postId: UUID, allowSave: Bool) async throws {
        print("🟡 [保存許可更新] 開始 - postId: \(postId), allowSave: \(allowSave)")
        
        do {
            try await SupabaseClient.shared.client
                .from("posts")
                .update(["allow_save": allowSave])
                .eq("id", value: postId.uuidString)
                .execute()
            
            print("✅ [保存許可更新] 成功")
        } catch {
            print("🔴 [保存許可更新] エラー: \(error)")
            throw error
        }
    }

    // MARK: - 人気のノード（中心テーマ）を取得
    func fetchPopularNodes(limit: Int = 10) async throws -> [String] {
        print("🟡 [人気ノード] 開始")
        
        struct PopularPost: Decodable {
            let center_node_text: String
            let like_count: Int
        }
        
        do {
            let posts: [PopularPost] = try await SupabaseClient.shared.client
                .from("posts")
                .select("center_node_text, like_count")
                .eq("is_deleted", value: false)
                .order("like_count", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            // 重複を除去してユニークなテーマを返す
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
    
    // PostService.swift に追加

    // MARK: - 投稿更新
    func updatePost(postId: UUID, isPinned: Bool? = nil, visibility: String? = nil, commentsEnabled: Bool? = nil) async throws {
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
            
            print("✅ [投稿更新] 成功")
        } catch {
            print("🔴 [投稿更新] エラー: \(error)")
            throw error
        }
    }
    
    // PostService.swift に追加

    // MARK: - ノード追加
    func addNode(postId: UUID, text: String, positionX: Double, positionY: Double, isCenter: Bool) async throws -> Node {
        print("🟡 [ノード追加] 開始 - postId: \(postId), text: \(text)")
        
        struct NodeInsert: Encodable {
            let post_id: String
            let text: String
            let position_x: Double
            let position_y: Double
            let is_center: Bool
        }
        
        do {
            let nodeInsert = NodeInsert(
                post_id: postId.uuidString,
                text: text,
                position_x: positionX,
                position_y: positionY,
                is_center: isCenter
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
    func addConnection(postId: UUID, fromNodeId: UUID, toNodeId: UUID, reason: String?) async throws {
        print("🟡 [コネクション追加] 開始")
        
        struct ConnectionInsert: Encodable {
            let post_id: String
            let from_node_id: String
            let to_node_id: String
            let reason: String?
        }
        
        do {
            let insert = ConnectionInsert(
                post_id: postId.uuidString,
                from_node_id: fromNodeId.uuidString,
                to_node_id: toNodeId.uuidString,
                reason: reason
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
    
    // MARK: - ノードテキストで検索
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
}
