// Services/DraftManager.swift

import Foundation
import Combine

class DraftManager: ObservableObject {
    static let shared = DraftManager()
    
    private let draftsKey = "saved_drafts"
    private let serverSaveCountKey = "server_save_count"
    private let serverSaveMonthKey = "server_save_month"
    private let maxDrafts = 12
    private let maxServerSavesPerMonth = 3
    
    @Published var drafts: [DraftPost] = []
    
    private init() {
        loadDrafts()
    }
    
    // MARK: - ドラフト操作
    
    func saveDraft(_ draft: DraftPost) -> Bool {
        // 最大数チェック
        if drafts.count >= maxDrafts && !drafts.contains(where: { $0.id == draft.id }) {
            return false
        }
        
        // 既存の下書きを更新または新規追加
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            var updatedDraft = draft
            updatedDraft.updatedAt = Date()
            drafts[index] = updatedDraft
        } else {
            drafts.insert(draft, at: 0)
        }
        
        persistDrafts()
        return true
    }
    
    func deleteDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
        persistDrafts()
    }
    
    func getDraft(id: UUID) -> DraftPost? {
        return drafts.first { $0.id == id }
    }
    
    var canSaveMoreDrafts: Bool {
        return drafts.count < maxDrafts
    }
    
    var remainingDraftSlots: Int {
        return maxDrafts - drafts.count
    }
    
    // MARK: - サーバー保存制限
    
    func canSaveToServer() -> Bool {
        resetMonthlyCountIfNeeded()
        let count = UserDefaults.standard.integer(forKey: serverSaveCountKey)
        return count < maxServerSavesPerMonth
    }
    
    func incrementServerSaveCount() {
        resetMonthlyCountIfNeeded()
        let count = UserDefaults.standard.integer(forKey: serverSaveCountKey)
        UserDefaults.standard.set(count + 1, forKey: serverSaveCountKey)
    }
    
    var remainingServerSaves: Int {
        resetMonthlyCountIfNeeded()
        let count = UserDefaults.standard.integer(forKey: serverSaveCountKey)
        return maxServerSavesPerMonth - count
    }
    
    private func resetMonthlyCountIfNeeded() {
        let currentMonth = getCurrentMonth()
        let savedMonth = UserDefaults.standard.string(forKey: serverSaveMonthKey) ?? ""
        
        if currentMonth != savedMonth {
            UserDefaults.standard.set(0, forKey: serverSaveCountKey)
            UserDefaults.standard.set(currentMonth, forKey: serverSaveMonthKey)
        }
    }
    
    private func getCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    // MARK: - 永続化
    
    private func loadDrafts() {
        guard let data = UserDefaults.standard.data(forKey: draftsKey) else {
            drafts = []
            return
        }
        
        do {
            drafts = try JSONDecoder().decode([DraftPost].self, from: data)
        } catch {
            print("🔴 [DraftManager] 読み込みエラー: \(error)")
            drafts = []
        }
    }
    
    private func persistDrafts() {
        do {
            let data = try JSONEncoder().encode(drafts)
            UserDefaults.standard.set(data, forKey: draftsKey)
        } catch {
            print("🔴 [DraftManager] 保存エラー: \(error)")
        }
    }
}
