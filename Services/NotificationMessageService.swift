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
                .select("*, actor:users!actor_id(*), post:posts(*)")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ [通知取得] 成功 - 件数: \(notifications.count)")
            return notifications
        } catch {
            print("🔴 [通知取得] エラー: \(error)")
            throw error
        }
    }
    
    func markAllAsRead(userId: UUID) async throws {
        print("🟡 [通知既読] 開始 - userId: \(userId)")
        
        do {
            try await SupabaseClient.shared.client
                .from("notifications")
                .update(["is_read": true])
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            print("✅ [通知既読] 成功")
        } catch {
            print("🔴 [通知既読] エラー: \(error)")
            throw error
        }
    }
    
    func getUnreadCount(userId: UUID) async throws -> Int {
        print("🟡 [未読数取得] 開始 - userId: \(userId)")
        
        do {
            let notifications: [AppNotification] = try await SupabaseClient.shared.client
                .from("notifications")
                .select()
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
                print("🟡 [会話一覧] 相手ユーザー取得 - otherId: \(otherId)")
                
                do {
                    conv.otherUser = try await SupabaseClient.shared.client
                        .from("users")
                        .select()
                        .eq("id", value: otherId.uuidString)
                        .single()
                        .execute()
                        .value
                    print("✅ [会話一覧] 相手ユーザー取得成功")
                } catch {
                    print("🔴 [会話一覧] 相手ユーザー取得エラー: \(error)")
                }
                result.append(conv)
            }
            
            print("✅ [会話一覧] 完了 - 件数: \(result.count)")
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

    func sendMessage(conversationId: UUID, senderId: UUID, content: String) async throws -> DMMessage {
        print("🟡 [メッセージ送信] 開始 - conversationId: \(conversationId), senderId: \(senderId)")
        print("🟡 [メッセージ送信] 内容: \(content)")
        
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
            
            print("✅ [メッセージ送信] 成功 - messageId: \(message.id)")
            
            // 会話の最終メッセージ時刻を更新
            print("🟡 [メッセージ送信] 会話更新中...")
            try await SupabaseClient.shared.client
                .from("conversations")
                .update(["last_message_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: conversationId.uuidString)
                .execute()
            
            print("✅ [メッセージ送信] 会話更新成功")
            return message
        } catch {
            print("🔴 [メッセージ送信] エラー: \(error)")
            throw error
        }
    }

    func deleteConversation(conversationId: UUID) async throws {
        print("🟡 [会話削除] 開始 - conversationId: \(conversationId)")
        
        do {
            // まずメッセージを削除
            print("🟡 [会話削除] メッセージ削除中...")
            try await SupabaseClient.shared.client
                .from("messages")
                .delete()
                .eq("conversation_id", value: conversationId.uuidString)
                .execute()
            
            print("✅ [会話削除] メッセージ削除成功")
            
            // 会話を削除
            print("🟡 [会話削除] 会話削除中...")
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
        print("🟡 [ピン切替] 開始 - conversationId: \(conversationId), isPinned: \(isPinned)")
        
        do {
            let conversation: Conversation = try await SupabaseClient.shared.client
                .from("conversations")
                .select()
                .eq("id", value: conversationId.uuidString)
                .single()
                .execute()
                .value
            
            let column = conversation.user1Id == userId ? "is_pinned_user1" : "is_pinned_user2"
            print("🟡 [ピン切替] 更新カラム: \(column)")
            
            try await SupabaseClient.shared.client
                .from("conversations")
                .update([column: isPinned])
                .eq("id", value: conversationId.uuidString)
                .execute()
            
            print("✅ [ピン切替] 成功")
        } catch {
            print("🔴 [ピン切替] エラー: \(error)")
            throw error
        }
    }
    
    func markAsRead(conversationId: UUID, userId: UUID) async throws {
        print("🟡 [既読処理] 開始 - conversationId: \(conversationId)")
        
        do {
            try await SupabaseClient.shared.client
                .from("messages")
                .update(["is_read": true])
                .eq("conversation_id", value: conversationId.uuidString)
                .neq("sender_id", value: userId.uuidString)
                .execute()
            
            print("✅ [既読処理] 成功")
        } catch {
            print("🔴 [既読処理] エラー: \(error)")
            throw error
        }
    }
    
    func createConversation(user1Id: UUID, user2Id: UUID) async throws -> Conversation {
        print("🟡 [会話作成] 開始 - user1: \(user1Id), user2: \(user2Id)")
        
        do {
            // 既存の会話があるか確認
            print("🟡 [会話作成] 既存会話を確認中...")
            let existing: [Conversation] = try await SupabaseClient.shared.client
                .from("conversations")
                .select()
                .or("and(user1_id.eq.\(user1Id.uuidString),user2_id.eq.\(user2Id.uuidString)),and(user1_id.eq.\(user2Id.uuidString),user2_id.eq.\(user1Id.uuidString))")
                .execute()
                .value
            
            if let existingConv = existing.first {
                print("✅ [会話作成] 既存の会話を返却 - id: \(existingConv.id)")
                return existingConv
            }
            
            // 新規作成
            print("🟡 [会話作成] 新規作成中...")
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
            
            print("✅ [会話作成] 新規作成成功 - id: \(conversation.id)")
            return conversation
        } catch {
            print("🔴 [会話作成] エラー: \(error)")
            throw error
        }
    }
}
