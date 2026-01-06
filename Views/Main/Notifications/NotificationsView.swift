import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var settingsManager = NotificationSettingsManager.shared
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var showSettings = false
    @State private var expandedGroups: Set<String> = []
    @State private var settings: NotificationSettings?
    @State private var selectedGroupForDetail: PostNotificationGroup?

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
                        ForEach(groupedByPostNotifications, id: \.id) { group in
                            postNotificationGroupRow(group: group)
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
            .sheet(item: $selectedGroupForDetail) { group in
                GroupedActorsSheet(group: group) { notification in
                    markAsRead(notification)
                }
            }
            .onAppear {
                if !hasLoaded {
                    hasLoaded = true
                    Task {
                        await loadNotifications()
                        await loadSettings()
                    }
                }
            }
            .refreshable {
                await loadNotifications()
            }
        }
    }

    // MARK: - Post-based Grouping Row
    @ViewBuilder
    private func postNotificationGroupRow(group: PostNotificationGroup) -> some View {
        if group.isGrouped {
            // まとめ表示
            GroupedPostNotificationRow(
                group: group,
                onTap: {
                    selectedGroupForDetail = group
                    markGroupAsRead(group)
                }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } else {
            // 単一通知
            if let notification = group.notifications.first {
                NotificationRow(
                    notification: notification,
                    onTap: { markAsRead(notification) }
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

    // MARK: - Post-based Grouping Logic
    private var groupedByPostNotifications: [PostNotificationGroup] {
        var result: [PostNotificationGroup] = []
        var grouped: [String: [AppNotification]] = [:]
        var order: [String] = []

        for notification in filteredNotifications {
            let batchCount = getBatchCount(for: notification.notificationType)

            // post_id + type でグループ化（batchCountが10の場合のみ）
            if batchCount == 10, let postId = notification.postId {
                let key = "\(postId.uuidString)_\(notification.type)"
                if grouped[key] == nil {
                    grouped[key] = []
                    order.append(key)
                }
                grouped[key]?.append(notification)
            } else if batchCount == 10 && notification.notificationType == .follow {
                // フォローは post_id がないので type だけでグループ化
                let key = "follow_group"
                if grouped[key] == nil {
                    grouped[key] = []
                    order.append(key)
                }
                grouped[key]?.append(notification)
            } else if batchCount == 10 && notification.notificationType == .dm {
                // DMは actorId でグループ化
                let key = "dm_\(notification.actorId.uuidString)"
                if grouped[key] == nil {
                    grouped[key] = []
                    order.append(key)
                }
                grouped[key]?.append(notification)
            } else {
                // 1件ごとに表示
                let key = notification.id.uuidString
                grouped[key] = [notification]
                order.append(key)
            }
        }

        for key in order {
            if let notifications = grouped[key], !notifications.isEmpty {
                let isGrouped = notifications.count > 1
                result.append(PostNotificationGroup(notifications: notifications, isGrouped: isGrouped))
            }
        }

        return result
    }

    private func getBatchCount(for type: NotificationType) -> Int {
        guard let settings = settings else { return 1 }
        switch type {
        case .like: return settings.likeBatchCount
        case .comment, .reply, .ownerReply: return settings.commentBatchCount
        case .follow: return settings.followBatchCount
        case .dm: return settings.dmBatchCount
        }
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

    private func loadSettings() async {
        guard let userId = authService.currentUser?.id else { return }
        do {
            if let fetched = try await PushNotificationService.shared.getNotificationSettings(userId: userId) {
                settings = fetched
            } else {
                settings = NotificationSettings.defaultSettings(userId: userId)
            }
        } catch {
            settings = NotificationSettings.defaultSettings(userId: userId)
        }
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

    private func markGroupAsRead(_ group: PostNotificationGroup) {
        Task {
            for notification in group.notifications where !notification.isRead {
                try? await NotificationService.shared.markAsRead(notificationId: notification.id)
                if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                    await MainActor.run {
                        notifications[index].isRead = true
                    }
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

// MARK: - Post-based Notification Group Model
struct PostNotificationGroup: Identifiable {
    let id: String
    let notifications: [AppNotification]
    let isGrouped: Bool

    init(notifications: [AppNotification], isGrouped: Bool = false) {
        self.notifications = notifications
        self.isGrouped = isGrouped
        if let first = notifications.first {
            if let postId = first.postId {
                self.id = "\(postId.uuidString)_\(first.type)"
            } else {
                self.id = "\(first.type)_\(first.id.uuidString)"
            }
        } else {
            self.id = UUID().uuidString
        }
    }

    var firstActor: User? { notifications.first?.actor }
    var otherCount: Int { max(0, notifications.count - 1) }
    var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    var notificationType: NotificationType { notifications.first?.notificationType ?? .like }

    var groupedMessage: String {
        guard let first = notifications.first else { return "" }
        let actorName = first.actor?.displayName ?? "ユーザー"

        if notifications.count == 1 {
            return "\(actorName)さんが\(first.notificationType.message)"
        } else {
            return "\(actorName)さん他\(otherCount)人が\(first.notificationType.message)"
        }
    }
}

// MARK: - Grouped Post Notification Row
struct GroupedPostNotificationRow: View {
    let group: PostNotificationGroup
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                // アバター（複数重ね）
                ZStack {
                    if group.notifications.count > 1 {
                        // 背面のアバター
                        if let secondActor = group.notifications.dropFirst().first?.actor {
                            ProfileAvatarView(user: secondActor, size: 36)
                                .offset(x: 12, y: 0)
                                .opacity(0.7)
                        }
                    }
                    // 前面のアバター
                    ProfileAvatarView(user: group.firstActor, size: 40)
                }
                .frame(width: 52, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.groupedMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Image(systemName: group.notificationType.icon)
                            .font(.caption)
                            .foregroundColor(group.notificationType.color)

                        Text(timeAgoText(from: group.notifications.first?.createdAt ?? Date()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if group.unreadCount > 0 {
                    Text("\(group.unreadCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple)
                        .cornerRadius(12)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .background(group.unreadCount > 0 ? Color.purple.opacity(0.05) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func timeAgoText(from date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "たった今" }
        else if diff < 3600 { return "\(Int(diff / 60))分前" }
        else if diff < 86400 { return "\(Int(diff / 3600))時間前" }
        else if diff < 604800 { return "\(Int(diff / 86400))日前" }
        else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Grouped Actors Sheet
struct GroupedActorsSheet: View {
    let group: PostNotificationGroup
    var onMarkAsRead: (AppNotification) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(group.notifications) { notification in
                    HStack(spacing: 12) {
                        ProfileAvatarView(user: notification.actor, size: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(notification.actor?.displayName ?? "ユーザー")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("@\(notification.actor?.username ?? "unknown")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !notification.isRead {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 8, height: 8)
                        }

                        Text(timeAgoText(from: notification.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onMarkAsRead(notification)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(group.notificationType.listTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func timeAgoText(from date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "たった今" }
        else if diff < 3600 { return "\(Int(diff / 60))分前" }
        else if diff < 86400 { return "\(Int(diff / 3600))時間前" }
        else { return "\(Int(diff / 86400))日前" }
    }
}

// MARK: - NotificationType Extension
extension NotificationType {
    var listTitle: String {
        switch self {
        case .like: return "いいねした人"
        case .comment: return "コメントした人"
        case .reply: return "返信した人"
        case .follow: return "フォローした人"
        case .dm: return "メッセージ"
        case .ownerReply: return "投稿者からの返信"
        }
    }
}

// MARK: - Legacy Models (keeping for compatibility)

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
    @EnvironmentObject var authService: AuthService
    @State private var settings: NotificationSettings?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let settings = Binding($settings) {
                    NotificationSettingsForm(settings: settings, onSave: saveSettings)
                } else {
                    Text("設定を読み込めませんでした")
                        .foregroundColor(.secondary)
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
        .presentationDetents([.large])
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }

        Task {
            do {
                if let fetched = try await PushNotificationService.shared.getNotificationSettings(userId: userId) {
                    await MainActor.run {
                        settings = fetched
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        settings = NotificationSettings.defaultSettings(userId: userId)
                        isLoading = false
                    }
                }
            } catch {
                print("🔴 [NotificationSettings] 読み込みエラー: \(error)")
                await MainActor.run {
                    settings = NotificationSettings.defaultSettings(userId: userId)
                    isLoading = false
                }
            }
        }
    }

    private func saveSettings() {
        guard let settings = settings else { return }
        Task {
            do {
                try await PushNotificationService.shared.saveNotificationSettings(settings: settings)
                print("✅ [NotificationSettings] 保存成功")
            } catch {
                print("🔴 [NotificationSettings] 保存エラー: \(error)")
            }
        }
    }
}

// MARK: - 通知設定フォーム
struct NotificationSettingsForm: View {
    @Binding var settings: NotificationSettings
    var onSave: () -> Void

    var body: some View {
        List {
            // いいね
            Section {
                Toggle(isOn: Binding(
                    get: { settings.likeInAppEnabled },
                    set: { settings.likeInAppEnabled = $0; onSave() }
                )) {
                    Label("アプリ内通知", systemImage: "bell.fill")
                }
                Toggle(isOn: Binding(
                    get: { settings.likePushEnabled },
                    set: { settings.likePushEnabled = $0; onSave() }
                )) {
                    Label("プッシュ通知", systemImage: "iphone.radiowaves.left.and.right")
                }
                batchCountRow(
                    value: Binding(
                        get: { settings.likeBatchCount },
                        set: { settings.likeBatchCount = $0; onSave() }
                    )
                )
            } header: {
                sectionHeader(title: "いいね", icon: "heart.fill", color: .pink)
            }
            .tint(.purple)

            // コメント
            Section {
                Toggle(isOn: Binding(
                    get: { settings.commentInAppEnabled },
                    set: { settings.commentInAppEnabled = $0; onSave() }
                )) {
                    Label("アプリ内通知", systemImage: "bell.fill")
                }
                Toggle(isOn: Binding(
                    get: { settings.commentPushEnabled },
                    set: { settings.commentPushEnabled = $0; onSave() }
                )) {
                    Label("プッシュ通知", systemImage: "iphone.radiowaves.left.and.right")
                }
                batchCountRow(
                    value: Binding(
                        get: { settings.commentBatchCount },
                        set: { settings.commentBatchCount = $0; onSave() }
                    )
                )
            } header: {
                sectionHeader(title: "コメント", icon: "bubble.right.fill", color: .blue)
            }
            .tint(.purple)

            // フォロー
            Section {
                Toggle(isOn: Binding(
                    get: { settings.followInAppEnabled },
                    set: { settings.followInAppEnabled = $0; onSave() }
                )) {
                    Label("アプリ内通知", systemImage: "bell.fill")
                }
                Toggle(isOn: Binding(
                    get: { settings.followPushEnabled },
                    set: { settings.followPushEnabled = $0; onSave() }
                )) {
                    Label("プッシュ通知", systemImage: "iphone.radiowaves.left.and.right")
                }
                batchCountRow(
                    value: Binding(
                        get: { settings.followBatchCount },
                        set: { settings.followBatchCount = $0; onSave() }
                    )
                )
            } header: {
                sectionHeader(title: "フォロー", icon: "person.fill.badge.plus", color: .green)
            }
            .tint(.purple)

            // DM
            Section {
                Toggle(isOn: Binding(
                    get: { settings.dmInAppEnabled },
                    set: { settings.dmInAppEnabled = $0; onSave() }
                )) {
                    Label("アプリ内通知", systemImage: "bell.fill")
                }
                Toggle(isOn: Binding(
                    get: { settings.dmPushEnabled },
                    set: { settings.dmPushEnabled = $0; onSave() }
                )) {
                    Label("プッシュ通知", systemImage: "iphone.radiowaves.left.and.right")
                }
                batchCountRow(
                    value: Binding(
                        get: { settings.dmBatchCount },
                        set: { settings.dmBatchCount = $0; onSave() }
                    )
                )
            } header: {
                sectionHeader(title: "DM", icon: "envelope.fill", color: .orange)
            }
            .tint(.purple)
        }
    }

    // MARK: - Section Header
    @ViewBuilder
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .foregroundColor(color)
            .font(.headline)
    }

    // MARK: - Batch Count Row
    @ViewBuilder
    private func batchCountRow(value: Binding<Int>) -> some View {
        HStack {
            Label("まとめ", systemImage: "square.stack.fill")

            Spacer()

            Picker("", selection: value) {
                Text("1件ごと").tag(1)
                Text("10件ごと").tag(10)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
    }
}
