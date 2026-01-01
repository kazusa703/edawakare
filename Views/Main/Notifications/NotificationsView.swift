// Views/Main/Notifications/NotificationsView.swift

import SwiftUI

// MARK: - 通知一覧画面
struct NotificationsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && notifications.isEmpty {
                    ProgressView()
                } else if notifications.isEmpty {
                    EmptyNotificationsView()
                } else {
                    List {
                        ForEach(notifications) { notification in
                            NotificationRow(notification: notification)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("通知")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !notifications.isEmpty {
                        Button("すべて既読") {
                            markAllAsRead()
                        }
                        .font(.subheadline)
                    }
                }
            }
            .task {
                await loadNotifications()
            }
            .refreshable {
                await loadNotifications()
            }
        }
    }
    
    private func loadNotifications() async {
        guard let userId = authService.currentUser?.id else { return }
        isLoading = true
        do {
            notifications = try await NotificationService.shared.fetchNotifications(userId: userId)
        } catch {
            print("🔴 [NotificationsView] loadNotifications error: \(error)")
        }
        isLoading = false
    }
    
    private func markAllAsRead() {
        guard let userId = authService.currentUser?.id else { return }
        Task {
            try? await NotificationService.shared.markAllAsRead(userId: userId)
            // ローカルの状態も更新
            for i in 0..<notifications.count {
                notifications[i].isRead = true
            }
        }
    }
}

// MARK: - 通知行
struct NotificationRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // アイコン
            notificationIcon
            
            // コンテンツ
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.actor?.displayName ?? "ユーザー")
                        .fontWeight(.semibold)
                    
                    Text(notificationText)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                
                if let centerText = notification.post?.centerNodeText {
                    Text(centerText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(timeAgoString(from: notification.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 未読インジケーター
            if !notification.isRead {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .opacity(notification.isRead ? 0.7 : 1.0)
    }
    
    @ViewBuilder
    private var notificationIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 44, height: 44)
            
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(.white)
        }
    }
    
    private var iconName: String {
        switch notification.type {
        case "like":
            return "heart.fill"
        case "comment":
            return "bubble.right.fill"
        case "follow":
            return "person.fill.badge.plus"
        default:
            return "bell.fill"
        }
    }
    
    private var iconBackgroundColor: Color {
        switch notification.type {
        case "like":
            return .pink
        case "comment":
            return .blue
        case "follow":
            return .purple
        default:
            return .gray
        }
    }
    
    private var notificationText: String {
        switch notification.type {
        case "like":
            return "があなたの投稿にいいねしました"
        case "comment":
            return "があなたの投稿にコメントしました"
        case "follow":
            return "があなたをフォローしました"
        default:
            return "から通知があります"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        
        if seconds < 60 {
            return "たった今"
        } else if seconds < 3600 {
            return "\(seconds / 60)分前"
        } else if seconds < 86400 {
            return "\(seconds / 3600)時間前"
        } else if seconds < 604800 {
            return "\(seconds / 86400)日前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 空の通知画面
struct EmptyNotificationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))
            
            Text("通知がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("いいね、コメント、フォローがあると\nここに表示されます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
