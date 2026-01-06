// Services/PushNotificationService.swift

import Foundation
import Supabase

class PushNotificationService {
    static let shared = PushNotificationService()
    private init() {}
    
    // MARK: - デバイストークン保存
    func saveDeviceToken(userId: UUID, fcmToken: String) async throws {
        struct TokenInsert: Encodable {
            let user_id: String
            let fcm_token: String
            let platform: String
            let updated_at: String
        }
        
        let insert = TokenInsert(
            user_id: userId.uuidString,
            fcm_token: fcmToken,
            platform: "ios",
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await SupabaseClient.shared.client
            .from("device_tokens")
            .upsert(insert, onConflict: "user_id, platform")
            .execute()
    }
    
    // MARK: - デバイストークン削除（ログアウト時）
    func deleteDeviceToken(userId: UUID) async throws {
        try await SupabaseClient.shared.client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("platform", value: "ios")
            .execute()
    }
    
    // MARK: - 通知設定取得
    func getNotificationSettings(userId: UUID) async throws -> NotificationSettings? {
        let settings: [NotificationSettings] = try await SupabaseClient.shared.client
            .from("notification_settings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        return settings.first
    }
    
    // MARK: - 通知設定保存
    func saveNotificationSettings(settings: NotificationSettings) async throws {
        try await SupabaseClient.shared.client
            .from("notification_settings")
            .upsert(settings)
            .execute()
    }
}

// MARK: - 通知設定モデル
struct NotificationSettings: Codable {
    let userId: UUID
    var likePushEnabled: Bool
    var likeInAppEnabled: Bool
    var commentPushEnabled: Bool
    var commentInAppEnabled: Bool
    var followPushEnabled: Bool
    var followInAppEnabled: Bool
    var dmPushEnabled: Bool
    var dmInAppEnabled: Bool
    var likeBatchCount: Int      // 1 or 10
    var commentBatchCount: Int   // 1 or 10
    var followBatchCount: Int    // 1 or 10
    var dmBatchCount: Int        // 1 or 10

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case likePushEnabled = "like_push_enabled"
        case likeInAppEnabled = "like_in_app_enabled"
        case commentPushEnabled = "comment_push_enabled"
        case commentInAppEnabled = "comment_in_app_enabled"
        case followPushEnabled = "follow_push_enabled"
        case followInAppEnabled = "follow_in_app_enabled"
        case dmPushEnabled = "dm_push_enabled"
        case dmInAppEnabled = "dm_in_app_enabled"
        case likeBatchCount = "like_batch_count"
        case commentBatchCount = "comment_batch_count"
        case followBatchCount = "follow_batch_count"
        case dmBatchCount = "dm_batch_count"
    }

    static func defaultSettings(userId: UUID) -> NotificationSettings {
        NotificationSettings(
            userId: userId,
            likePushEnabled: true,
            likeInAppEnabled: true,
            commentPushEnabled: true,
            commentInAppEnabled: true,
            followPushEnabled: true,
            followInAppEnabled: true,
            dmPushEnabled: true,
            dmInAppEnabled: true,
            likeBatchCount: 1,
            commentBatchCount: 1,
            followBatchCount: 1,
            dmBatchCount: 1
        )
    }
}
