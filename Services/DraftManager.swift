// Services/DraftManager.swift

import Foundation
import SwiftUI
import Combine

class DraftManager: ObservableObject {
    static let shared = DraftManager()
    
    // MARK: - Published Properties
    @Published var localDrafts: [DraftPost] = []
    @Published var serverDrafts: [ServerDraft] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Constants
    private let draftsKey = "saved_drafts"
    private let serverSaveCountKey = "server_save_count"
    private let lastResetMonthKey = "last_reset_month"
    
    private let maxLocalDrafts = 12
    private let maxServerDrafts = 3
    private let maxServerSavesPerMonth = 3
    
    private init() {
        loadLocalDrafts()
        checkAndResetMonthlyCount()
    }
    
    // MARK: - Computed Properties
    
    /// ローカル保存可能か
    var canSaveLocalDraft: Bool {
        localDrafts.count < maxLocalDrafts
    }
    
    /// 残りローカル保存枠
    var remainingLocalSlots: Int {
        max(0, maxLocalDrafts - localDrafts.count)
    }
    
    /// サーバー保存可能か（月3回制限 + 最大3件制限）
    var canSaveToServer: Bool {
        checkAndResetMonthlyCount()
        return getServerSaveCount() < maxServerSavesPerMonth && serverDrafts.count < maxServerDrafts
    }
    
    /// 残りサーバー保存回数（今月）
    var remainingServerSaves: Int {
        checkAndResetMonthlyCount()
        return max(0, maxServerSavesPerMonth - getServerSaveCount())
    }
    
    /// 残りサーバー保存枠
    var remainingServerSlots: Int {
        max(0, maxServerDrafts - serverDrafts.count)
    }
    
    /// 全下書き（サーバー + ローカル、更新日時順）
    var allDrafts: [DraftDisplayItem] {
        var items: [DraftDisplayItem] = []
        
        // サーバー下書き
        items += serverDrafts.map { DraftDisplayItem(serverDraft: $0) }
        
        // ローカル下書き
        items += localDrafts.map { DraftDisplayItem(localDraft: $0) }
        
        // 更新日時でソート（新しい順）
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    // MARK: - サーバー下書き操作
    
    /// サーバーから下書き取得
    func fetchServerDrafts(userId: UUID) async {
        await MainActor.run { isLoading = true }
        
        do {
            let drafts = try await DraftService.shared.fetchDrafts(userId: userId)
            await MainActor.run {
                serverDrafts = drafts
                isLoading = false
            }
            print("✅ [DraftManager] サーバー下書き取得完了 - 件数: \(drafts.count)")
        } catch {
            await MainActor.run {
                errorMessage = "サーバー下書きの取得に失敗しました"
                isLoading = false
            }
            print("🔴 [DraftManager] サーバー下書き取得エラー: \(error)")
        }
    }
    
    /// サーバーに下書き保存
    func saveToServer(userId: UUID, draft: DraftPost) async -> Bool {
        guard canSaveToServer else {
            await MainActor.run {
                errorMessage = "今月のサーバー保存回数（3回）を超えました"
            }
            return false
        }
        
        await MainActor.run { isLoading = true }
        
        do {
            let savedDraft = try await DraftService.shared.saveDraft(userId: userId, draft: draft)
            await MainActor.run {
                serverDrafts.insert(savedDraft, at: 0)
                incrementServerSaveCount()
                isLoading = false
            }
            print("✅ [DraftManager] サーバー保存成功")
            return true
        } catch {
            await MainActor.run {
                errorMessage = "サーバーへの保存に失敗しました"
                isLoading = false
            }
            print("🔴 [DraftManager] サーバー保存エラー: \(error)")
            return false
        }
    }
    
    /// サーバー下書き更新
    func updateServerDraft(draftId: UUID, draft: DraftPost) async -> Bool {
        await MainActor.run { isLoading = true }
        
        do {
            let updatedDraft = try await DraftService.shared.updateDraft(draftId: draftId, draft: draft)
            await MainActor.run {
                if let index = serverDrafts.firstIndex(where: { $0.id == draftId }) {
                    serverDrafts[index] = updatedDraft
                }
                isLoading = false
            }
            print("✅ [DraftManager] サーバー下書き更新成功")
            return true
        } catch {
            await MainActor.run {
                errorMessage = "更新に失敗しました"
                isLoading = false
            }
            print("🔴 [DraftManager] サーバー下書き更新エラー: \(error)")
            return false
        }
    }
    
    /// サーバー下書き削除
    func deleteServerDraft(draftId: UUID) async -> Bool {
        await MainActor.run { isLoading = true }
        
        do {
            try await DraftService.shared.deleteDraft(draftId: draftId)
            await MainActor.run {
                serverDrafts.removeAll { $0.id == draftId }
                isLoading = false
            }
            print("✅ [DraftManager] サーバー下書き削除成功")
            return true
        } catch {
            await MainActor.run {
                errorMessage = "削除に失敗しました"
                isLoading = false
            }
            print("🔴 [DraftManager] サーバー下書き削除エラー: \(error)")
            return false
        }
    }
    
    // MARK: - ローカル下書き操作
    
    /// ローカルに下書き保存
    @discardableResult
    func saveLocalDraft(_ draft: DraftPost) -> Bool {
        guard canSaveLocalDraft else { return false }
        localDrafts.insert(draft, at: 0)
        saveLocalDraftsToStorage()
        return true
    }
    
    /// ローカル下書き更新
    func updateLocalDraft(_ draft: DraftPost) {
        if let index = localDrafts.firstIndex(where: { $0.id == draft.id }) {
            var updatedDraft = draft
            updatedDraft.updatedAt = Date()
            localDrafts[index] = updatedDraft
            saveLocalDraftsToStorage()
        }
    }
    
    /// ローカル下書き削除
    func deleteLocalDraft(id: UUID) {
        localDrafts.removeAll { $0.id == id }
        saveLocalDraftsToStorage()
    }
    
    /// ローカルからサーバーへ移動
    func moveToServer(userId: UUID, localDraftId: UUID) async -> Bool {
        guard let draft = localDrafts.first(where: { $0.id == localDraftId }) else {
            return false
        }
        
        let success = await saveToServer(userId: userId, draft: draft)
        if success {
            await MainActor.run {
                deleteLocalDraft(id: localDraftId)
            }
        }
        return success
    }
    
    // MARK: - Private Methods
    
    private func loadLocalDrafts() {
        guard let data = UserDefaults.standard.data(forKey: draftsKey),
              let decoded = try? JSONDecoder().decode([DraftPost].self, from: data) else {
            return
        }
        localDrafts = decoded
    }
    
    private func saveLocalDraftsToStorage() {
        guard let encoded = try? JSONEncoder().encode(localDrafts) else { return }
        UserDefaults.standard.set(encoded, forKey: draftsKey)
    }
    
    private func getServerSaveCount() -> Int {
        UserDefaults.standard.integer(forKey: serverSaveCountKey)
    }
    
    private func incrementServerSaveCount() {
        let current = getServerSaveCount()
        UserDefaults.standard.set(current + 1, forKey: serverSaveCountKey)
    }
    
    @discardableResult
    private func checkAndResetMonthlyCount() -> Bool {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentYearMonth = currentYear * 100 + currentMonth
        
        let lastResetMonth = UserDefaults.standard.integer(forKey: lastResetMonthKey)
        
        if lastResetMonth != currentYearMonth {
            UserDefaults.standard.set(0, forKey: serverSaveCountKey)
            UserDefaults.standard.set(currentYearMonth, forKey: lastResetMonthKey)
            return true
        }
        return false
    }
}

// MARK: - 下書き表示用アイテム
struct DraftDisplayItem: Identifiable {
    let id: UUID
    let centerNodeText: String
    let updatedAt: Date
    let isServerDraft: Bool
    let localDraft: DraftPost?
    let serverDraft: ServerDraft?
    
    init(localDraft: DraftPost) {
        self.id = localDraft.id
        self.centerNodeText = localDraft.centerNodeText
        self.updatedAt = localDraft.updatedAt
        self.isServerDraft = false
        self.localDraft = localDraft
        self.serverDraft = nil
    }
    
    init(serverDraft: ServerDraft) {
        self.id = serverDraft.id
        self.centerNodeText = serverDraft.centerNodeText
        self.updatedAt = serverDraft.updatedAt
        self.isServerDraft = true
        self.localDraft = nil
        self.serverDraft = serverDraft
    }
    
    /// DraftPostに変換（編集画面用）
    func toDraftPost() -> DraftPost {
        if let local = localDraft {
            return local
        } else if let server = serverDraft {
            return DraftPost(
                id: server.id,
                centerNodeText: server.centerNodeText,
                nodes: server.nodes,
                connections: server.connections,
                createdAt: server.createdAt,
                updatedAt: server.updatedAt
            )
        }
        fatalError("Neither local nor server draft available")
    }
}

// MARK: - 旧API互換（既存コードが壊れないように）
extension DraftManager {
    /// 旧: drafts プロパティ（ローカルのみ）
    var drafts: [DraftPost] {
        get { localDrafts }
        set { localDrafts = newValue }
    }
    
    /// 旧: canSaveMoreDrafts
    var canSaveMoreDrafts: Bool { canSaveLocalDraft }
    
    /// 旧: remainingDraftSlots
    var remainingDraftSlots: Int { remainingLocalSlots }
    
    /// 旧: saveDraft
    @discardableResult
    func saveDraft(_ draft: DraftPost) -> Bool {
        saveLocalDraft(draft)
    }
    
    /// 旧: updateDraft
    func updateDraft(_ draft: DraftPost) {
        updateLocalDraft(draft)
    }
    
    /// 旧: deleteDraft
    func deleteDraft(id: UUID) {
        deleteLocalDraft(id: id)
    }
}
