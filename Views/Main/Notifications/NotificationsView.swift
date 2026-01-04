import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var settingsManager = NotificationSettingsManager.shared
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var showSettings = false
    @State private var expandedGroups: Set<String> = []
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if filteredNotifications.isEmpty {
                    EmptyNotificationsView()
                } else {
                    List {
                        ForEach(groupedNotifications, id: \.id) { group in
                            notificationGroupRow(group: group)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if filteredNotifications.contains(where: { !$0.isRead }) {
                        Button("全て既読") {
                            markAllAsRead()
                        }
                        .font(.subheadline)
                    }
                    
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NotificationSettingsSheet()
            }
            .onAppear {
                if !hasLoaded {
                    hasLoaded = true
                    Task {
                        await loadNotifications()
                    }
                }
            }
            .refreshable {
                await loadNotifications()
            }
        }
    }
    
    @ViewBuilder
    private func notificationGroupRow(group: NotificationGroup) -> some View {
        if group.isGrouped && !expandedGroups.contains(group.id) {
            GroupedNotificationRow(
                group: group,
                onTap: {
                    withAnimation {
                        // 修正点: 結果を無視することを明示してエラーを回避
                        _ = expandedGroups.insert(group.id)
                    }
                }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } else if group.isGrouped && expandedGroups.contains(group.id) {
            Section {
                HStack {
                    Text("\(group.typeName) \(group.notifications.count)件")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(group.color)
                    Spacer()
                    Button("閉じる") {
                        withAnimation {
                            // 修正点: 同様に結果を無視する
                            _ = expandedGroups.remove(group.id)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                
                ForEach(group.notifications) { notification in
                    NotificationRow(
                        notification: notification,
                        onTap: { markAsRead(notification) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 32, bottom: 4, trailing: 16))
                }
            }
        } else {
            if let firstNotification = group.notifications.first {
                NotificationRow(
                    notification: firstNotification,
                    onTap: { markAsRead(firstNotification) }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }
    
    private var filteredNotifications: [AppNotification] {
        notifications.filter { notification in
            settingsManager.isEnabled(for: notification.notificationType)
        }
    }
    
    private var groupedNotifications: [NotificationGroup] {
        guard settingsManager.groupingEnabled else {
            return filteredNotifications.map { NotificationGroup(notifications: [$0]) }
        }
        
        var typeGroups: [String: [AppNotification]] = [:]
        
        for notification in filteredNotifications {
            let key = notification.type
            if typeGroups[key] == nil {
                typeGroups[key] = []
            }
            typeGroups[key]?.append(notification)
        }
        
        var result: [NotificationGroup] = []
        var processedTypes: Set<String> = []
        
        for notification in filteredNotifications {
            let type = notification.type
            if processedTypes.contains(type) { continue }
            
            let group = typeGroups[type] ?? []
            if group.count >= settingsManager.groupingThreshold {
                result.append(NotificationGroup(notifications: group, isGrouped: true))
            } else {
                for n in group {
                    result.append(NotificationGroup(notifications: [n], isGrouped: false))
                }
            }
            processedTypes.insert(type)
        }
        return result
    }
    
    private func loadNotifications() async {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            try? await NotificationService.shared.deleteOldNotifications(userId: userId)
            notifications = try await NotificationService.shared.fetchNotifications(userId: userId)
        } catch {
            print("🔴 [NotificationsView] 取得エラー: \(error)")
        }
        isLoading = false
    }
    
    private func markAsRead(_ notification: AppNotification) {
        guard !notification.isRead else { return }
        Task {
            try? await NotificationService.shared.markAsRead(notificationId: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                await MainActor.run {
                    notifications[index].isRead = true
                }
            }
        }
    }
    
    private func markAllAsRead() {
        guard let userId = authService.currentUser?.id else { return }
        Task {
            try? await NotificationService.shared.markAllAsRead(userId: userId)
            await MainActor.run {
                for i in notifications.indices {
                    notifications[i].isRead = true
                }
            }
        }
    }
}

// MARK: - Models / Helper Views (通知行など) は変更なしのため省略せず含めます

struct NotificationGroup: Identifiable {
    let id: String
    let notifications: [AppNotification]
    let isGrouped: Bool
    
    init(notifications: [AppNotification], isGrouped: Bool = false) {
        self.notifications = notifications
        self.isGrouped = isGrouped
        if isGrouped, let first = notifications.first {
            self.id = "group_\(first.type)"
        } else if let first = notifications.first {
            self.id = first.id.uuidString
        } else {
            self.id = UUID().uuidString
        }
    }
    
    var typeName: String {
        guard let first = notifications.first else { return "" }
        switch first.notificationType {
        case .like: return "いいね"
        case .comment: return "コメント"
        case .reply: return "返信"
        case .follow: return "フォロー"
        case .dm: return "メッセージ"
        case .ownerReply: return "投稿者からの返信"
        }
    }
    var color: Color { notifications.first?.notificationType.color ?? .gray }
    var icon: String { notifications.first?.notificationType.icon ?? "bell" }
}

struct GroupedNotificationRow: View {
    let group: NotificationGroup
    var onTap: () -> Void
    var unreadCount: Int { group.notifications.filter { !$0.isRead }.count }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(group.color.opacity(0.2)).frame(width: 44, height: 44)
                    Image(systemName: group.icon).font(.system(size: 18)).foregroundColor(group.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(group.typeName) \(group.notifications.count)件").font(.subheadline).fontWeight(.semibold)
                    Text("タップして展開").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if unreadCount > 0 {
                    Text("\(unreadCount)").font(.caption).fontWeight(.bold).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.purple).cornerRadius(12)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .background(unreadCount > 0 ? Color.purple.opacity(0.05) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyNotificationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell").font(.system(size: 60)).foregroundColor(.secondary)
            Text("通知はありません").font(.headline).foregroundColor(.secondary)
            Text("いいねやコメント、フォローされると\nここに表示されます").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(notification.notificationType.color.opacity(0.2)).frame(width: 44, height: 44)
                    Image(systemName: notification.notificationType.icon).font(.system(size: 18)).foregroundColor(notification.notificationType.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(notification.actor?.displayName ?? "ユーザー").fontWeight(.semibold)
                        Text(notification.notificationType.message).foregroundColor(.secondary)
                    }
                    .font(.subheadline).lineLimit(2)
                    Text(timeAgoText).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if !notification.isRead {
                    Circle().fill(Color.purple).frame(width: 10, height: 10)
                }
            }
            .padding(.vertical, 4)
            .background(notification.isRead ? Color.clear : Color.purple.opacity(0.05))
        }
        .buttonStyle(PlainButtonStyle())
    }
    private var timeAgoText: String {
        let now = Date()
        let diff = now.timeIntervalSince(notification.createdAt)
        if diff < 60 { return "たった今" }
        else if diff < 3600 { return "\(Int(diff / 60))分前" }
        else if diff < 86400 { return "\(Int(diff / 3600))時間前" }
        else if diff < 604800 { return "\(Int(diff / 86400))日前" }
        else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: notification.createdAt)
        }
    }
}

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = NotificationSettingsManager.shared
    var body: some View {
        NavigationStack {
            List {
                Section("通知タイプ") {
                    Toggle(isOn: $settings.likeEnabled) { Label("いいね", systemImage: "heart.fill").foregroundColor(.pink) }
                    Toggle(isOn: $settings.commentEnabled) { Label("コメント", systemImage: "bubble.right.fill").foregroundColor(.blue) }
                    Toggle(isOn: $settings.replyEnabled) { Label("返信", systemImage: "arrowshape.turn.up.left.fill").foregroundColor(.purple) }
                    Toggle(isOn: $settings.followEnabled) { Label("フォロー", systemImage: "person.fill.badge.plus").foregroundColor(.green) }
                    Toggle(isOn: $settings.dmEnabled) { Label("メッセージ", systemImage: "envelope.fill").foregroundColor(.orange) }
                    Toggle(isOn: $settings.ownerReplyEnabled) { Label("投稿者からの返信", systemImage: "tag.fill").foregroundColor(.cyan) }
                }
                .tint(.purple)
                Section("表示設定") {
                    Toggle(isOn: $settings.groupingEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("通知をまとめる")
                            Text("同じ種類の通知が\(settings.groupingThreshold)件以上ある時にまとめて表示").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .tint(.purple)
                    if settings.groupingEnabled {
                        Stepper(value: $settings.groupingThreshold, in: 5...50, step: 5) {
                            HStack {
                                Text("まとめる件数")
                                Spacer()
                                Text("\(settings.groupingThreshold)件").foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("通知設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
