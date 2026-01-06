// Services/DraftService.swift

import Foundation
import Supabase

// MARK: - サーバー用下書きモデル
struct ServerDraft: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var centerNodeText: String
    var nodes: [DraftNode]
    var connections: [DraftConnection]
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case centerNodeText = "center_node_text"
        case nodes
        case connections
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 下書き作成用
struct CreateDraftRequest: Codable {
    let userId: UUID
    let centerNodeText: String
    let nodes: [DraftNode]
    let connections: [DraftConnection]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case centerNodeText = "center_node_text"
        case nodes
        case connections
    }
}

// MARK: - 下書き更新用
struct UpdateDraftRequest: Codable {
    let centerNodeText: String
    let nodes: [DraftNode]
    let connections: [DraftConnection]
    
    enum CodingKeys: String, CodingKey {
        case centerNodeText = "center_node_text"
        case nodes
        case connections
    }
}

// MARK: - DraftService
class DraftService {
    static let shared = DraftService()
    private let client = SupabaseClient.shared.client
    
    private init() {}
    
    // MARK: - サーバーから下書き取得
    func fetchDrafts(userId: UUID) async throws -> [ServerDraft] {
        print("🟡 [DraftService] 下書き取得開始 - userId: \(userId)")
        
        let response: [ServerDraft] = try await client
            .from("drafts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        print("✅ [DraftService] 下書き取得完了 - 件数: \(response.count)")
        return response
    }
    
    // MARK: - サーバーに下書き保存
    func saveDraft(userId: UUID, draft: DraftPost) async throws -> ServerDraft {
        print("🟡 [DraftService] 下書き保存開始")
        
        let request = CreateDraftRequest(
            userId: userId,
            centerNodeText: draft.centerNodeText,
            nodes: draft.nodes,
            connections: draft.connections
        )
        
        let response: ServerDraft = try await client
            .from("drafts")
            .insert(request)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ [DraftService] 下書き保存完了 - id: \(response.id)")
        return response
    }
    
    // MARK: - サーバーの下書き更新
    func updateDraft(draftId: UUID, draft: DraftPost) async throws -> ServerDraft {
        print("🟡 [DraftService] 下書き更新開始 - id: \(draftId)")
        
        let request = UpdateDraftRequest(
            centerNodeText: draft.centerNodeText,
            nodes: draft.nodes,
            connections: draft.connections
        )
        
        let response: ServerDraft = try await client
            .from("drafts")
            .update(request)
            .eq("id", value: draftId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ [DraftService] 下書き更新完了")
        return response
    }
    
    // MARK: - サーバーの下書き削除
    func deleteDraft(draftId: UUID) async throws {
        print("🟡 [DraftService] 下書き削除開始 - id: \(draftId)")
        
        try await client
            .from("drafts")
            .delete()
            .eq("id", value: draftId.uuidString)
            .execute()
        
        print("✅ [DraftService] 下書き削除完了")
    }
    
    // MARK: - サーバーの下書き件数取得
    func getDraftCount(userId: UUID) async throws -> Int {
        let drafts: [ServerDraft] = try await client
            .from("drafts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        return drafts.count
    }
}
