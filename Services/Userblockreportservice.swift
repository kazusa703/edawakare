// Services/UserBlockReportService.swift
// ユーザー・ブロック・通報サービス

import Foundation
import Supabase

// MARK: - UserService
class UserService {
    static let shared = UserService()
    
    private init() {}
    
    // MARK: - ユーザー取得
        func fetchUser(userId: UUID) async throws -> User {
            print("🟡 [ユーザー取得] 開始 - userId: \(userId)")
            
            do {
                let user: User = try await SupabaseClient.shared.client
                    .from("users")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                print("✅ [ユーザー取得] 成功 - username: \(user.username)")
                return user
            } catch {
                print("🔴 [ユーザー取得] エラー: \(error)")
                throw error
            }
        }
    
    // MARK: - ユーザー検索（ユーザー名）
    func searchUsers(query: String) async throws -> [User] {
        let users: [User] = try await SupabaseClient.shared.client
            .from("users")
            .select()
            .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
            .limit(20)
            .execute()
            .value
        
        return users
    }
    
    // MARK: - アバター画像アップロード
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        let fileName = "\(userId.uuidString)/avatar.jpg"
        
        try await SupabaseClient.shared.client.storage
            .from("avatars")
            .upload(
                path: fileName,
                file: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
        
        // 公開URLを取得
        let publicURL = try SupabaseClient.shared.client.storage
            .from("avatars")
            .getPublicURL(path: fileName)
        
        // usersテーブルを更新
        let update = AvatarUpdate(avatar_url: publicURL.absoluteString)
        try await SupabaseClient.shared.client
            .from("users")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
        
        return publicURL.absoluteString
    }
    
    // MARK: - プロフィール更新
    func updateProfile(userId: UUID, displayName: String, username: String, bio: String?) async throws {
        let update = ProfileUpdate(
            display_name: displayName,
            username: username,
            bio: bio
        )
        
        try await SupabaseClient.shared.client
            .from("users")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    // MARK: - プライバシー設定更新
    func updatePrivacySettings(userId: UUID, isPrivate: Bool, dmPermission: String) async throws {
        let update = PrivacyUpdate(
            is_private: isPrivate,
            dm_permission: dmPermission
        )
        
        try await SupabaseClient.shared.client
            .from("users")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
    }
}

// MARK: - Update用の構造体
struct AvatarUpdate: Encodable {
    let avatar_url: String
}

struct ProfileUpdate: Encodable {
    let display_name: String
    let username: String
    let bio: String?
}

struct PrivacyUpdate: Encodable {
    let is_private: Bool
    let dm_permission: String
}

// MARK: - BlockReportService
class BlockReportService {
    static let shared = BlockReportService()
    
    private init() {}
    
    // MARK: - ブロック
    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        let insert = BlockInsert(
            blocker_id: blockerId.uuidString,
            blocked_id: blockedId.uuidString
        )
        
        try await SupabaseClient.shared.client
            .from("blocks")
            .insert(insert)
            .execute()
        
        // フォロー関係も解除
        try? await InteractionService.shared.unfollow(followerId: blockerId, followingId: blockedId)
        try? await InteractionService.shared.unfollow(followerId: blockedId, followingId: blockerId)
    }
    
    // MARK: - ブロック解除
    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        try await SupabaseClient.shared.client
            .from("blocks")
            .delete()
            .eq("blocker_id", value: blockerId.uuidString)
            .eq("blocked_id", value: blockedId.uuidString)
            .execute()
    }
    
    // MARK: - ブロックしているか確認
    func isBlocked(blockerId: UUID, blockedId: UUID) async throws -> Bool {
        let blocks: [Block] = try await SupabaseClient.shared.client
            .from("blocks")
            .select()
            .eq("blocker_id", value: blockerId.uuidString)
            .eq("blocked_id", value: blockedId.uuidString)
            .execute()
            .value
        
        return !blocks.isEmpty
    }
    
    // MARK: - ブロックリスト取得
    func fetchBlockedUsers(blockerId: UUID) async throws -> [User] {
        let blocks: [Block] = try await SupabaseClient.shared.client
            .from("blocks")
            .select("blocked:users!blocked_id(*)")
            .eq("blocker_id", value: blockerId.uuidString)
            .execute()
            .value
        
        return blocks.compactMap { $0.blockedUser }
    }
    
    // MARK: - 通報（ユーザー）
    func reportUser(reporterId: UUID, reportedUserId: UUID, reason: String, detail: String?) async throws {
        let insert = UserReportInsert(
            reporter_id: reporterId.uuidString,
            reported_user_id: reportedUserId.uuidString,
            reason: reason,
            detail: detail
        )
        
        try await SupabaseClient.shared.client
            .from("reports")
            .insert(insert)
            .execute()
    }
    
    // MARK: - 通報（投稿）
    func reportPost(reporterId: UUID, reportedPostId: UUID, reason: String, detail: String?) async throws {
        let insert = PostReportInsert(
            reporter_id: reporterId.uuidString,
            reported_post_id: reportedPostId.uuidString,
            reason: reason,
            detail: detail
        )
        
        try await SupabaseClient.shared.client
            .from("reports")
            .insert(insert)
            .execute()
    }
}

// MARK: - Insert用の構造体
struct BlockInsert: Encodable {
    let blocker_id: String
    let blocked_id: String
}

struct UserReportInsert: Encodable {
    let reporter_id: String
    let reported_user_id: String
    let reason: String
    let detail: String?
}

struct PostReportInsert: Encodable {
    let reporter_id: String
    let reported_post_id: String
    let reason: String
    let detail: String?
}
