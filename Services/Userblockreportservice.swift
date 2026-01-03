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
        print("🟡 [ユーザー検索] 開始 - query: \(query)")
        
        do {
            let users: [User] = try await SupabaseClient.shared.client
                .from("users")
                .select()
                .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
                .limit(20)
                .execute()
                .value
            
            print("✅ [ユーザー検索] 成功 - 件数: \(users.count)")
            return users
        } catch {
            print("🔴 [ユーザー検索] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - おすすめユーザーを取得（自分以外）
    func fetchRecommendedUsers(currentUserId: UUID?, limit: Int = 5) async throws -> [User] {
        print("🟡 [おすすめユーザー] 開始")
        
        do {
            let users: [User]
            
            if let userId = currentUserId {
                users = try await SupabaseClient.shared.client
                    .from("users")
                    .select("*")
                    .neq("id", value: userId.uuidString)
                    .order("total_branches", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
            } else {
                users = try await SupabaseClient.shared.client
                    .from("users")
                    .select("*")
                    .order("total_branches", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
            }
            
            print("✅ [おすすめユーザー] 成功 - 件数: \(users.count)")
            return users
        } catch {
            print("🔴 [おすすめユーザー] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - アバター画像アップロード
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        print("🟡 [アバターアップロード] 開始")
        
        let fileName = "\(userId.uuidString)/avatar.jpg"
        
        do {
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
            
            let publicURL = try SupabaseClient.shared.client.storage
                .from("avatars")
                .getPublicURL(path: fileName)
            
            let update = AvatarUpdate(avatar_url: publicURL.absoluteString)
            try await SupabaseClient.shared.client
                .from("users")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()
            
            print("✅ [アバターアップロード] 成功")
            return publicURL.absoluteString
        } catch {
            print("🔴 [アバターアップロード] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - プロフィール更新
    func updateProfile(userId: UUID, displayName: String, username: String, bio: String?) async throws {
        print("🟡 [プロフィール更新] 開始")
        
        let update = ProfileUpdate(
            display_name: displayName,
            username: username,
            bio: bio
        )
        
        do {
            try await SupabaseClient.shared.client
                .from("users")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()
            
            print("✅ [プロフィール更新] 成功")
        } catch {
            print("🔴 [プロフィール更新] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - プライバシー設定更新
    func updatePrivacySettings(userId: UUID, isPrivate: Bool, dmPermission: String) async throws {
        print("🟡 [プライバシー設定更新] 開始")
        
        let update = PrivacyUpdate(
            is_private: isPrivate,
            dm_permission: dmPermission
        )
        
        do {
            try await SupabaseClient.shared.client
                .from("users")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()
            
            print("✅ [プライバシー設定更新] 成功")
        } catch {
            print("🔴 [プライバシー設定更新] エラー: \(error)")
            throw error
        }
    }
}

// MARK: - BlockReportService
class BlockReportService {
    static let shared = BlockReportService()
    
    private init() {}
    
    // MARK: - ブロック
    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        print("🟡 [ブロック] 開始")
        
        let insert = BlockInsert(
            blocker_id: blockerId.uuidString,
            blocked_id: blockedId.uuidString
        )
        
        do {
            try await SupabaseClient.shared.client
                .from("blocks")
                .insert(insert)
                .execute()
            
            // フォロー関係も解除
            try? await InteractionService.shared.unfollow(followerId: blockerId, followingId: blockedId)
            try? await InteractionService.shared.unfollow(followerId: blockedId, followingId: blockerId)
            
            print("✅ [ブロック] 成功")
        } catch {
            print("🔴 [ブロック] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - ブロック解除
    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        print("🟡 [ブロック解除] 開始")
        
        do {
            try await SupabaseClient.shared.client
                .from("blocks")
                .delete()
                .eq("blocker_id", value: blockerId.uuidString)
                .eq("blocked_id", value: blockedId.uuidString)
                .execute()
            
            print("✅ [ブロック解除] 成功")
        } catch {
            print("🔴 [ブロック解除] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - ブロックしているか確認
    func isBlocked(blockerId: UUID, blockedId: UUID) async throws -> Bool {
        print("🟡 [ブロック確認] 開始")
        
        do {
            let blocks: [Block] = try await SupabaseClient.shared.client
                .from("blocks")
                .select()
                .eq("blocker_id", value: blockerId.uuidString)
                .eq("blocked_id", value: blockedId.uuidString)
                .execute()
                .value
            
            let result = !blocks.isEmpty
            print("✅ [ブロック確認] 結果: \(result)")
            return result
        } catch {
            print("🔴 [ブロック確認] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - ブロックリスト取得
    func fetchBlockedUsers(blockerId: UUID) async throws -> [User] {
        print("🟡 [ブロックリスト取得] 開始")
        
        do {
            let blocks: [Block] = try await SupabaseClient.shared.client
                .from("blocks")
                .select("blocked:users!blocked_id(*)")
                .eq("blocker_id", value: blockerId.uuidString)
                .execute()
                .value
            
            let users = blocks.compactMap { $0.blockedUser }
            print("✅ [ブロックリスト取得] 成功 - 件数: \(users.count)")
            return users
        } catch {
            print("🔴 [ブロックリスト取得] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 通報（ユーザー）
    func reportUser(reporterId: UUID, reportedUserId: UUID, reason: String, detail: String?) async throws {
        print("🟡 [ユーザー通報] 開始")
        
        let insert = UserReportInsert(
            reporter_id: reporterId.uuidString,
            reported_user_id: reportedUserId.uuidString,
            reason: reason,
            detail: detail
        )
        
        do {
            try await SupabaseClient.shared.client
                .from("reports")
                .insert(insert)
                .execute()
            
            print("✅ [ユーザー通報] 成功")
        } catch {
            print("🔴 [ユーザー通報] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 通報（投稿）
    func reportPost(reporterId: UUID, reportedPostId: UUID, reason: String, detail: String?) async throws {
        print("🟡 [投稿通報] 開始")
        
        let insert = PostReportInsert(
            reporter_id: reporterId.uuidString,
            reported_post_id: reportedPostId.uuidString,
            reason: reason,
            detail: detail
        )
        
        do {
            try await SupabaseClient.shared.client
                .from("reports")
                .insert(insert)
                .execute()
            
            print("✅ [投稿通報] 成功")
        } catch {
            print("🔴 [投稿通報] エラー: \(error)")
            throw error
        }
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
