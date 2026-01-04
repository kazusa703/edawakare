// Services/DraftManager.swift

import Foundation
import SwiftUI
import Combine

class DraftManager: ObservableObject {
    static let shared = DraftManager()
    
    @Published var drafts: [DraftPost] = []
    
    private let draftsKey = "saved_drafts"
    private let serverSaveCountKey = "server_save_count"
    private let lastResetMonthKey = "last_reset_month"
    
    private let maxLocalDrafts = 12
    private let maxServerSavesPerMonth = 3
    
    private init() {
        loadDraftsFromStorage()
        checkAndResetMonthlyCount()
    }
    
    // MARK: - ローカル保存可能かチェック
    var canSaveMoreDrafts: Bool {
        drafts.count < maxLocalDrafts
    }
    
    // MARK: - 残りローカル保存枠
    var remainingDraftSlots: Int {
        max(0, maxLocalDrafts - drafts.count)
    }
    
    // MARK: - サーバー保存可能かチェック
    func canSaveToServer() -> Bool {
        checkAndResetMonthlyCount()
        return getServerSaveCount() < maxServerSavesPerMonth
    }
    
    // MARK: - 残りサーバー保存回数
    var remainingServerSaves: Int {
        checkAndResetMonthlyCount()
        return max(0, maxServerSavesPerMonth - getServerSaveCount())
    }
    
    // MARK: - 下書き保存
    @discardableResult
    func saveDraft(_ draft: DraftPost) -> Bool {
        guard canSaveMoreDrafts else { return false }
        drafts.insert(draft, at: 0)
        saveDraftsToStorage()
        return true
    }
    
    // MARK: - 下書き更新
    func updateDraft(_ draft: DraftPost) {
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
            saveDraftsToStorage()
        }
    }
    
    // MARK: - 下書き削除
    func deleteDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
        saveDraftsToStorage()
    }
    
    // MARK: - サーバー保存カウント増加
    func incrementServerSaveCount() {
        let current = getServerSaveCount()
        UserDefaults.standard.set(current + 1, forKey: serverSaveCountKey)
    }
    
    // MARK: - Private Methods
    private func loadDraftsFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: draftsKey),
              let decoded = try? JSONDecoder().decode([DraftPost].self, from: data) else {
            return
        }
        drafts = decoded
    }
    
    private func saveDraftsToStorage() {
        guard let encoded = try? JSONEncoder().encode(drafts) else { return }
        UserDefaults.standard.set(encoded, forKey: draftsKey)
    }
    
    private func getServerSaveCount() -> Int {
        UserDefaults.standard.integer(forKey: serverSaveCountKey)
    }
    
    private func checkAndResetMonthlyCount() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentYearMonth = currentYear * 100 + currentMonth
        
        let lastResetMonth = UserDefaults.standard.integer(forKey: lastResetMonthKey)
        
        if lastResetMonth != currentYearMonth {
            UserDefaults.standard.set(0, forKey: serverSaveCountKey)
            UserDefaults.standard.set(currentYearMonth, forKey: lastResetMonthKey)
        }
    }
}
