// Services/NotificationMessageService.swift
import Foundation
import Supabase

// MARK: - 通知サービス
class NotificationService {
    static let shared = NotificationService()
    private init() {}
    
    func fetchNotifications(userId: UUID) async throws -> [AppNotification] {
        print("🟡 [通知取得] 開始 - userId: \(userId)")
        
        do {
            let notifications: [AppNotification] = try await SupabaseClient.shared.client
                .from("notifications")
                .select("*, actor:users!actor_id(*)")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            print("✅ [通知取得] 成功 - 件数: \(notifications.count)")
            return notifications
        } catch {
            print("🔴 [通知取得] エラー: \(error)")
            throw error
        }
    }
    
    func markAsRead(notificationId: UUID) async throws {
        print("🟡 [通知既読] 開始 - notificationId: \(notificationId)")
        
        do {
            try await SupabaseClient.shared.client
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notificationId.uuidString)
                .execute()
            
            print("✅ [通知既読] 成功")
        } catch {
            print("🔴 [通知既読] エラー: \(error)")
            throw error
        }
    }
    
    func markAllAsRead(userId: UUID) async throws {
        print("🟡 [全通知既読] 開始 - userId: \(userId)")
        
        do {
            try await SupabaseClient.shared.client
                .from("notifications")
                .update(["is_read": true])
                .eq("user_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()
            
            print("✅ [全通知既読] 成功")
        } catch {
            print("🔴 [全通知既読] エラー: \(error)")
            throw error
        }
    }
    
    func getUnreadCount(userId: UUID) async throws -> Int {
        print("🟡 [未読数取得] 開始 - userId: \(userId)")
        
        struct CountOnly: Decodable {
            let id: UUID
        }
        
        do {
            let notifications: [CountOnly] = try await SupabaseClient.shared.client
                .from("notifications")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()
                .value
            
            print("✅ [未読数取得] 成功 - 件数: \(notifications.count)")
            return notifications.count
        } catch {
            print("🔴 [未読数取得] エラー: \(error)")
            throw error
        }
    }
    
    // MARK: - 30日経過した通知を削除
    func deleteOldNotifications(userId: UUID) async throws {
        print("🟡 [古い通知削除] 開始")
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: thirtyDaysAgo)
        
        do {
            try await SupabaseClient.shared.client
                .from("notifications")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .lt("created_at", value: dateString)
                .execute()
            
            print("✅ [古い通知削除] 成功")
        } catch {
            print("🔴 [古い通知削除] エラー: \(error)")
            // エラーは無視（削除できなくても問題ない）
        }
    }
}

// MARK: - メッセージ（DM）サービス
class MessageService {
    static let shared = MessageService()
    private init() {}
    
    func fetchConversations(userId: UUID) async throws -> [Conversation] {
        print("🟡 [会話一覧] 開始 - userId: \(userId)")
        
        do {
            let conversations: [Conversation] = try await SupabaseClient.shared.client
                .from("conversations")
                .select("*")
                .or("user1_id.eq.\(userId.uuidString),user2_id.eq.\(userId.uuidString)")
                .order("last_message_at", ascending: false)
                .execute()
                .value
            
            print("✅ [会話一覧] 取得成功 - 件数: \(conversations.count)")
            
            var result: [Conversation] = []
            for var conv in conversations {
                let otherId = conv.user1Id == userId ? conv.user2Id : conv.user1Id
                
                do {
                    conv.otherUser = try await SupabaseClient.shared.client
                        .from("users")
                        .select()
                        .eq("id", value: otherId.uuidString)
                        .single()
                        .execute()
                        .value
                } catch {
                    print("🔴 [会話一覧] 相手ユーザー取得エラー: \(error)")
                }
                result.append(conv)
            }
            
            return result
        } catch {
            print("🔴 [会話一覧] エラー: \(error)")
            throw error
        }
    }

    func fetchMessages(conversationId: UUID) async throws -> [DMMessage] {
        print("🟡 [メッセージ取得] 開始 - conversationId: \(conversationId)")
        
        do {
            let messages: [DMMessage] = try await SupabaseClient.shared.client
                .from("messages")
                .select("*, sender:users!sender_id(*)")
                .eq("conversation_id", value: conversationId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            print("✅ [メッセージ取得] 成功 - 件数: \(messages.count)")
            return messages
        } catch {
            print("🔴 [メッセージ取得] エラー: \(error)")
            throw error
        }
    }

    func sendMessage(conversationId: UUID, senderId: UUID, receiverId: UUID, content: String) async throws -> DMMessage {
        print("🟡 [メッセージ送信] 開始")
        
        struct MessageInsert: Encodable {
            let conversation_id: String
            let sender_id: String
            let content: String
        }
        
        let insertData = MessageInsert(
            conversation_id: conversationId.uuidString,
            sender_id: senderId.uuidString,
            content: content
        )
        
        do {
            let message: DMMessage = try await SupabaseClient.shared.client
                .from("messages")
                .insert(insertData)
                .select("*, sender:users!sender_id(*)")
                .single()
                .execute()
                .value
            
            // 会話の最終メッセージ時刻を更新
            try await SupabaseClient.shared.client
                .from("conversations")
                .update(["last_message_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: conversationId.uuidString)
                .execute()
            
            // ✅ DM通知を作成
            try await createDMNotification(receiverId: receiverId, senderId: senderId)
            
            print("✅ [メッセージ送信] 成功")
            return message
        } catch {
            print("🔴 [メッセージ送信] エラー: \(error)")
            throw error
        }
    }
    
    // DM通知を作成
    private func createDMNotification(receiverId: UUID, senderId: UUID) async throws {
        // 自分自身には通知しない
        guard receiverId != senderId else { return }
        
        print("🟡 [DM通知] 開始")
        
        struct NotificationInsert: Encodable {
            let user_id: String
            let actor_id: String
            let type: String
        }
        
        let notification = NotificationInsert(
            user_id: receiverId.uuidString,
            actor_id: senderId.uuidString,
            type: "dm"
        )
        
        do {
            try await SupabaseClient.shared.client
                .from("notifications")
                .insert(notification)
                .execute()
            print("✅ [DM通知] 成功")
        } catch {
            print("🔴 [DM通知] エラー: \(error)")
        }
    }

    func deleteConversation(conversationId: UUID) async throws {
        print("🟡 [会話削除] 開始")
        
        do {
            try await SupabaseClient.shared.client
                .from("messages")
                .delete()
                .eq("conversation_id", value: conversationId.uuidString)
                .execute()
            
            try await SupabaseClient.shared.client
                .from("conversations")
                .delete()
                .eq("id", value: conversationId.uuidString)
                .execute()
            
            print("✅ [会話削除] 成功")
        } catch {
            print("🔴 [会話削除] エラー: \(error)")
            throw error
        }
    }
    
    func togglePin(conversationId: UUID, userId: UUID, isPinned: Bool) async throws {
        do {
            let conversation: Conversation = try await SupabaseClient.shared.client
                .from("conversations")
                .select()
                .eq("id", value: conversationId.uuidString)
                .single()
                .execute()
                .value
            
            let column = conversation.user1Id == userId ? "is_pinned_user1" : "is_pinned_user2"
            
            try await SupabaseClient.shared.client
                .from("conversations")
                .update([column: isPinned])
                .eq("id", value: conversationId.uuidString)
                .execute()
        } catch {
            print("🔴 [ピン切替] エラー: \(error)")
            throw error
        }
    }
    
    func markAsRead(conversationId: UUID, userId: UUID) async throws {
        do {
            try await SupabaseClient.shared.client
                .from("messages")
                .update(["is_read": true])
                .eq("conversation_id", value: conversationId.uuidString)
                .neq("sender_id", value: userId.uuidString)
                .execute()
        } catch {
            print("🔴 [既読処理] エラー: \(error)")
            throw error
        }
    }
    
    func createConversation(user1Id: UUID, user2Id: UUID) async throws -> Conversation {
        do {
            let existing: [Conversation] = try await SupabaseClient.shared.client
                .from("conversations")
                .select()
                .or("and(user1_id.eq.\(user1Id.uuidString),user2_id.eq.\(user2Id.uuidString)),and(user1_id.eq.\(user2Id.uuidString),user2_id.eq.\(user1Id.uuidString))")
                .execute()
                .value
            
            if let existingConv = existing.first {
                return existingConv
            }
            
            struct ConversationInsert: Encodable {
                let user1_id: String
                let user2_id: String
            }
            
            let conversation: Conversation = try await SupabaseClient.shared.client
                .from("conversations")
                .insert(ConversationInsert(user1_id: user1Id.uuidString, user2_id: user2Id.uuidString))
                .select()
                .single()
                .execute()
                .value
            
            return conversation
        } catch {
            print("🔴 [会話作成] エラー: \(error)")
            throw error
        }
    }
}
