// Services/NotificationSettingsManager.swift

import Foundation
import Combine

class NotificationSettingsManager: ObservableObject {
    static let shared = NotificationSettingsManager()
    
    // 各通知タイプのオン/オフ
    @Published var likeEnabled: Bool {
        didSet { UserDefaults.standard.set(likeEnabled, forKey: "notification_like") }
    }
    @Published var commentEnabled: Bool {
        didSet { UserDefaults.standard.set(commentEnabled, forKey: "notification_comment") }
    }
    @Published var replyEnabled: Bool {
        didSet { UserDefaults.standard.set(replyEnabled, forKey: "notification_reply") }
    }
    @Published var followEnabled: Bool {
        didSet { UserDefaults.standard.set(followEnabled, forKey: "notification_follow") }
    }
    @Published var dmEnabled: Bool {
        didSet { UserDefaults.standard.set(dmEnabled, forKey: "notification_dm") }
    }
    @Published var ownerReplyEnabled: Bool {
        didSet { UserDefaults.standard.set(ownerReplyEnabled, forKey: "notification_owner_reply") }
    }
    
    // 通知をまとめる機能のオン/オフ
    @Published var groupingEnabled: Bool {
        didSet { UserDefaults.standard.set(groupingEnabled, forKey: "notification_grouping") }
    }
    
    // グループ化する閾値（デフォルト10件）
    @Published var groupingThreshold: Int {
        didSet { UserDefaults.standard.set(groupingThreshold, forKey: "notification_grouping_threshold") }
    }
    
    private init() {
        // UserDefaultsから読み込み（デフォルトは全てtrue）
        self.likeEnabled = UserDefaults.standard.object(forKey: "notification_like") as? Bool ?? true
        self.commentEnabled = UserDefaults.standard.object(forKey: "notification_comment") as? Bool ?? true
        self.replyEnabled = UserDefaults.standard.object(forKey: "notification_reply") as? Bool ?? true
        self.followEnabled = UserDefaults.standard.object(forKey: "notification_follow") as? Bool ?? true
        self.dmEnabled = UserDefaults.standard.object(forKey: "notification_dm") as? Bool ?? true
        self.ownerReplyEnabled = UserDefaults.standard.object(forKey: "notification_owner_reply") as? Bool ?? true
        self.groupingEnabled = UserDefaults.standard.object(forKey: "notification_grouping") as? Bool ?? true
        self.groupingThreshold = UserDefaults.standard.object(forKey: "notification_grouping_threshold") as? Int ?? 10
    }
    
    // 指定タイプの通知が有効かチェック
    func isEnabled(for type: NotificationType) -> Bool {
        switch type {
        case .like: return likeEnabled
        case .comment: return commentEnabled
        case .reply: return replyEnabled
        case .follow: return followEnabled
        case .dm: return dmEnabled
        case .ownerReply: return ownerReplyEnabled
        }
    }
}
