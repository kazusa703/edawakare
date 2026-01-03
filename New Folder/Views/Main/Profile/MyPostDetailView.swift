// Views/Main/Profile/MyPostDetailView.swift

import SwiftUI

struct MyPostDetailView: View {
    @State var post: Post
    var onUpdate: () async -> Void
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var showMenu = false
    @State private var showDeleteAlert = false
    @State private var showEditPost = false
    @State private var showComments = false
    @State private var showLikedUsers = false
    @State private var showPrivacySettings = false
    @State private var showCommentSettings = false
    @State private var showReasonPopup = false
    @State private var selectedReason = ""
    
    // フローティングメニュー用
    @State private var menuPosition: CGPoint = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    @State private var isMenuMinimized = false
    @State private var minimizedEdge: Edge = .trailing
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // マインドマップ表示
                MindMapDisplayView(
                    post: post,
                    onShowReason: { reason in
                        selectedReason = reason
                        showReasonPopup = true
                    }
                )
                
                // 理由ポップアップ
                if showReasonPopup {
                    ReasonDisplayPopup(
                        reason: selectedReason,
                        onDismiss: { showReasonPopup = false }
                    )
                }
                
                // フローティングメニュー
                if showMenu {
                    // 背景タップで閉じる（メニュー展開時のみ）
                    if !isMenuMinimized {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    showMenu = false
                                }
                            }
                    }
                    
                    FloatingMenuView(
                        post: $post,
                        isMinimized: $isMenuMinimized,
                        minimizedEdge: $minimizedEdge,
                        position: $menuPosition,
                        geometry: geometry,
                        onClose: {
                            withAnimation(.spring(response: 0.3)) {
                                showMenu = false
                                isMenuMinimized = false
                            }
                        },
                        onDelete: { showDeleteAlert = true },
                        onTogglePin: { togglePin() },
                        onEdit: { showEditPost = true },
                        onShowLikedUsers: { showLikedUsers = true },
                        onCopyLink: { copyLink() },
                        onPrivacySettings: { showPrivacySettings = true },
                        onCommentSettings: { showCommentSettings = true }
                    )
                }
            }
        }
        .navigationTitle(post.centerNodeText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // コメントボタン（追加）
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showComments = true }) {
                    Image(systemName: "bubble.right")
                }
            }
            
            // メニューボタン
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showMenu = true
                        isMenuMinimized = false
                        menuPosition = CGPoint(
                            x: UIScreen.main.bounds.width / 2,
                            y: UIScreen.main.bounds.height / 2
                        )
                    }
                }) {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .alert("投稿を削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) { deletePost() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません")
        }
        .sheet(isPresented: $showEditPost) {
            EditPostView(post: post, onSave: {
                Task {
                    await refreshPost()
                    await onUpdate()
                }
            })
            .environmentObject(authService)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showLikedUsers) {
            LikedUsersView(postId: post.id)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showPrivacySettings) {
            PrivacySettingsSheet(
                currentVisibility: post.visibility,
                onSave: { newVisibility in
                    updateVisibility(newVisibility)
                }
            )
        }
        .sheet(isPresented: $showCommentSettings) {
            CommentSettingsSheet(
                commentsEnabled: post.commentsEnabled,
                onSave: { enabled in
                    updateCommentsEnabled(enabled)
                }
            )
        }
    }
    
    // MARK: - Actions
    
    private func togglePin() {
        Task {
            do {
                try await PostService.shared.updatePost(postId: post.id, isPinned: !post.isPinned)
                post.isPinned.toggle()
                await onUpdate()
            } catch {
                print("🔴 [MyPostDetail] ピン留め変更エラー: \(error)")
            }
        }
    }
    
    // MyPostDetailView.swift の deletePost() を修正

    private func deletePost() {
        Task {
            do {
                try await PostService.shared.deletePost(postId: post.id)
                
                // ✅ 投稿削除の通知を発火
                NotificationCenter.default.post(name: .postDeleted, object: nil)
                
                await onUpdate()
                dismiss()
            } catch {
                print("🔴 [MyPostDetail] 削除エラー: \(error)")
            }
        }
    }
    
    private func copyLink() {
        let link = "edawakare://post/\(post.id.uuidString)"
        UIPasteboard.general.string = link
        
        // フィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func updateVisibility(_ visibility: String) {
        Task {
            do {
                try await PostService.shared.updatePost(postId: post.id, visibility: visibility)
                post.visibility = visibility
                await onUpdate()
            } catch {
                print("🔴 [MyPostDetail] 公開範囲変更エラー: \(error)")
            }
        }
    }
    
    private func updateCommentsEnabled(_ enabled: Bool) {
        Task {
            do {
                try await PostService.shared.updatePost(postId: post.id, commentsEnabled: enabled)
                post.commentsEnabled = enabled
                await onUpdate()
            } catch {
                print("🔴 [MyPostDetail] コメント設定変更エラー: \(error)")
            }
        }
    }
    
    private func refreshPost() async {
        do {
            post = try await PostService.shared.fetchPost(postId: post.id)
        } catch {
            print("🔴 [MyPostDetail] 投稿更新エラー: \(error)")
        }
    }
}

// MARK: - フローティングメニュー
struct FloatingMenuView: View {
    @Binding var post: Post
    @Binding var isMinimized: Bool
    @Binding var minimizedEdge: Edge
    @Binding var position: CGPoint
    let geometry: GeometryProxy
    
    var onClose: () -> Void
    var onDelete: () -> Void
    var onTogglePin: () -> Void
    var onEdit: () -> Void
    var onShowLikedUsers: () -> Void
    var onCopyLink: () -> Void
    var onPrivacySettings: () -> Void
    var onCommentSettings: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var velocity: CGSize = .zero
    @State private var lastDragValue: DragGesture.Value?
    
    var body: some View {
        Group {
            if isMinimized {
                // 最小化状態
                MinimizedMenuTab(edge: minimizedEdge) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isMinimized = false
                        position = CGPoint(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                    }
                }
                .position(
                    x: minimizedEdge == .leading ? 20 : geometry.size.width - 20,
                    y: position.y
                )
            } else {
                // 展開状態
                ExpandedMenuView(
                    post: post,
                    onClose: onClose,
                    onDelete: onDelete,
                    onTogglePin: onTogglePin,
                    onEdit: onEdit,
                    onShowLikedUsers: onShowLikedUsers,
                    onCopyLink: onCopyLink,
                    onPrivacySettings: onPrivacySettings,
                    onCommentSettings: onCommentSettings
                )
                .position(
                    x: position.x + dragOffset.width,
                    y: position.y + dragOffset.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                            
                            // 速度計算
                            if let last = lastDragValue {
                                let timeDiff = value.time.timeIntervalSince(last.time)
                                if timeDiff > 0 {
                                    velocity = CGSize(
                                        width: (value.translation.width - last.translation.width) / timeDiff,
                                        height: (value.translation.height - last.translation.height) / timeDiff
                                    )
                                }
                            }
                            lastDragValue = value
                        }
                        .onEnded { value in
                            let newX = position.x + value.translation.width
                            let newY = position.y + value.translation.height
                            
                            // 速度が速い場合は最小化
                            let speed = sqrt(velocity.width * velocity.width + velocity.height * velocity.height)
                            
                            if speed > 800 || newX < 50 || newX > geometry.size.width - 50 {
                                // 最小化
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isMinimized = true
                                    minimizedEdge = newX < geometry.size.width / 2 ? .leading : .trailing
                                    position.y = min(max(newY, 100), geometry.size.height - 100)
                                    dragOffset = .zero
                                }
                            } else {
                                // 位置更新
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    position = CGPoint(
                                        x: min(max(newX, 100), geometry.size.width - 100),
                                        y: min(max(newY, 150), geometry.size.height - 150)
                                    )
                                    dragOffset = .zero
                                }
                            }
                            
                            velocity = .zero
                            lastDragValue = nil
                        }
                )
            }
        }
    }
}

// MARK: - 最小化タブ
struct MinimizedMenuTab: View {
    let edge: Edge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 8)
                    .frame(width: 40, height: 60)
                
                Image(systemName: edge == .leading ? "chevron.right" : "chevron.left")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
        }
    }
}

// MARK: - 展開メニュー
struct ExpandedMenuView: View {
    let post: Post
    var onClose: () -> Void
    var onDelete: () -> Void
    var onTogglePin: () -> Void
    var onEdit: () -> Void
    var onShowLikedUsers: () -> Void
    var onCopyLink: () -> Void
    var onPrivacySettings: () -> Void
    var onCommentSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // ハンドル
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // メニュー項目
            VStack(spacing: 0) {
                MenuItemRow(icon: "pin.fill", title: post.isPinned ? "ピン留め解除" : "ピン留め", iconColor: .orange) {
                    onTogglePin()
                    onClose()
                }
                
                Divider().padding(.horizontal)
                
                MenuItemRow(icon: "pencil", title: "ノードを追加", iconColor: .purple) {
                    onEdit()
                    onClose()
                }
                
                Divider().padding(.horizontal)
                
                MenuItemRow(icon: "heart.fill", title: "いいねしたユーザー", iconColor: .pink) {
                    onShowLikedUsers()
                    onClose()
                }
                
                Divider().padding(.horizontal)
                
                MenuItemRow(icon: "link", title: "リンクをコピー", iconColor: .blue) {
                    onCopyLink()
                    onClose()
                }
                
                Divider().padding(.horizontal)
                
                MenuItemRow(
                    icon: post.visibility == "public" ? "globe" : "lock.fill",
                    title: "プライバシー設定",
                    subtitle: post.visibility == "public" ? "全員" : "フォロワーのみ",
                    iconColor: .green
                ) {
                    onPrivacySettings()
                    onClose()
                }
                
                Divider().padding(.horizontal)
                
                MenuItemRow(
                    icon: post.commentsEnabled ? "bubble.left.fill" : "bubble.left.and.exclamationmark.bubble.right.fill",
                    title: "コメント設定",
                    subtitle: post.commentsEnabled ? "ON" : "OFF",
                    iconColor: .cyan
                ) {
                    onCommentSettings()
                    onClose()
                }
                
                Divider().padding(.horizontal)
                
                MenuItemRow(icon: "trash.fill", title: "削除", iconColor: .red, isDestructive: true) {
                    onDelete()
                    onClose()
                }
            }
            .padding(.bottom, 12)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.25), radius: 20)
        )
    }
}

// MARK: - メニュー項目行
struct MenuItemRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let iconColor: Color
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isDestructive ? .red : iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - いいねしたユーザー一覧
struct LikedUsersView: View {
    let postId: UUID
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var users: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("まだいいねがありません")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(users) { user in
                        NavigationLink(destination: UserProfileView(userId: user.id)) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(
                                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(String(user.displayName.prefix(1)))
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("いいねしたユーザー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await loadLikedUsers()
            }
        }
    }
    
    private func loadLikedUsers() async {
        do {
            users = try await InteractionService.shared.fetchLikedUsers(
                postId: postId,
                excludeUserId: authService.currentUser?.id
            )
        } catch {
            print("🔴 [LikedUsers] 取得エラー: \(error)")
        }
        isLoading = false
    }
}

// MARK: - プライバシー設定シート
struct PrivacySettingsSheet: View {
    let currentVisibility: String
    var onSave: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedVisibility: String = "public"
    
    var body: some View {
        NavigationStack {
            List {
                Section("公開範囲") {
                    Button(action: { selectedVisibility = "public" }) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text("一般公開")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("すべてのユーザーが閲覧可能")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedVisibility == "public" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    
                    Button(action: { selectedVisibility = "followers_only" }) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text("フォロワー限定")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("フォロワーのみ閲覧可能")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedVisibility == "followers_only" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
            .navigationTitle("プライバシー設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(selectedVisibility)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedVisibility = currentVisibility
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - コメント設定シート
struct CommentSettingsSheet: View {
    let commentsEnabled: Bool
    var onSave: (Bool) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var isEnabled: Bool = true
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $isEnabled) {
                        HStack {
                            Image(systemName: isEnabled ? "bubble.left.fill" : "bubble.left.and.exclamationmark.bubble.right.fill")
                                .foregroundColor(isEnabled ? .cyan : .gray)
                            Text("コメントを許可")
                        }
                    }
                    .tint(.purple)
                } footer: {
                    Text("オフにすると、この投稿へのコメントができなくなります。既存のコメントは表示されたままです。")
                }
            }
            .navigationTitle("コメント設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(isEnabled)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isEnabled = commentsEnabled
            }
        }
        .presentationDetents([.medium])
    }
}
