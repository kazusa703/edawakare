// Views/Main/Home/HomeFeedView.swift

import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    HomeFeedSkeleton()
                } else if currentPosts.isEmpty {
                    HomeFeedEmptyView(selectedTab: selectedTab)
                } else {
                    TabView {
                        ForEach(currentPosts) { post in
                            HomePostCardView(post: post)
                                .environmentObject(authService)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle(selectedTab == 0 ? "おすすめ" : "フォロー中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("枝分かれ")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = selectedTab == 0 ? 1 : 0
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: selectedTab == 0 ? "person.2.fill" : "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .refreshable {
                await loadPosts()
            }
            .task {
                await loadPosts()
            }
            .onChange(of: selectedTab) { _, _ in
                Task {
                    await loadPosts()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .postCreated)) { _ in
                Task {
                    await viewModel.fetchPosts()
                    if let userId = authService.currentUser?.id {
                        await viewModel.fetchFollowingPosts(userId: userId)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .postDeleted)) { _ in
                Task {
                    await viewModel.fetchPosts()
                    if let userId = authService.currentUser?.id {
                        await viewModel.fetchFollowingPosts(userId: userId)
                    }
                }
            }
        }
    }
    
    private var currentPosts: [Post] {
        selectedTab == 0 ? viewModel.posts : viewModel.followingPosts
    }
    
    private func loadPosts() async {
        if selectedTab == 0 {
            await viewModel.fetchPosts()
        } else {
            if let userId = authService.currentUser?.id {
                await viewModel.fetchFollowingPosts(userId: userId)
            }
        }
    }
}

// MARK: - 空のフィードView（名前変更で重複回避）
struct HomeFeedEmptyView: View {
    let selectedTab: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: selectedTab == 0 ? "sparkles" : "person.2")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))
            
            Text(selectedTab == 0 ? "まだ投稿がありません" : "フォロー中のユーザーの投稿がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(selectedTab == 0 ? "最初の投稿を作成してみましょう！" : "ユーザーをフォローして\n興味の繋がりを見つけましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 投稿カードView（名前変更で重複回避）
struct HomePostCardView: View {
    let post: Post
    @EnvironmentObject var authService: AuthService
    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var likeCount: Int = 0
    @State private var showComments = false
    @State private var showFullMap = false
    @State private var showLikeAnimation = false
    @State private var showReasonPopup = false
    @State private var selectedReason = ""
    @State private var likeScale: CGFloat = 1.0
    @State private var bookmarkRotation: Double = 0
    @State private var bookmarkScale: CGFloat = 1.0
    @State private var showDMSheet = false
    @State private var showDMErrorAlert = false
    @State private var dmErrorMessage = ""

    private var isOwnPost: Bool {
        authService.currentUser?.id == post.userId
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                
                MindMapDisplayView(
                    post: post,
                    onShowReason: { reason in
                        selectedReason = reason
                        showReasonPopup = true
                    },
                    isFixedDisplay: true  // フィード表示は固定
                )
                .frame(width: geometry.size.width, height: geometry.size.height * 0.7)
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)
                
                if showLikeAnimation {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.pink)
                        .transition(.scale.combined(with: .opacity))
                }
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    NavigationLink(destination: UserProfileView(userId: post.userId)) {
                        if let user = post.user {
                            UserAvatarView(
                                user: user,
                                size: 44,
                                showMutualBorder: true,
                                currentUserId: authService.currentUser?.id
                            )
                        } else {
                            Circle()
                                .fill(AppColors.primaryGradient)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("?")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    
                    Button(action: { toggleLike() }) {
                        VStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.title)
                                .foregroundColor(isLiked ? .pink : .primary)
                                .scaleEffect(likeScale)
                            // いいね数非表示設定
                            if !post.hideLikeCount {
                                Text("\(likeCount)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    // コメントオフの場合は非表示
                    if post.commentsEnabled {
                        Button(action: { showComments = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "bubble.right")
                                    .font(.title)
                                Text("\(post.commentCount)")
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    
                    Button(action: { showFullMap = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                            Text("詳細")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Button(action: { toggleBookmark() }) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.title)
                            .foregroundColor(isBookmarked ? .purple : .primary)
                            .scaleEffect(bookmarkScale)
                            .rotationEffect(.degrees(bookmarkRotation))
                    }

                    // DMボタン（自分の投稿には非表示）
                    if !isOwnPost {
                        Button(action: { startDMFromPost() }) {
                            Image(systemName: "envelope")
                                .font(.title)
                                .foregroundColor(.primary)
                        }
                    }

                    ShareLink(item: "枝分かれで「\(post.centerNodeText)」を見つけました！") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                VStack {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("@\(post.user?.username ?? "unknown")")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(post.centerNodeText)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                if showReasonPopup {
                    HomeReasonPopup(
                        reason: selectedReason,
                        onDismiss: { showReasonPopup = false }
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if !isLiked {
                    toggleLike()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        showLikeAnimation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation {
                            showLikeAnimation = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showDMSheet) {
            DMFromPostSheet(post: post)
                .environmentObject(authService)
        }
        .fullScreenCover(isPresented: $showFullMap) {
            HomeFullMapView(post: post)
                .environmentObject(authService)
        }
        .alert("DMを送れません", isPresented: $showDMErrorAlert) {
            Button("OK") { }
        } message: {
            Text(dmErrorMessage)
        }
        .onAppear {
            likeCount = post.likeCount
            checkLikeAndBookmarkStatus()
        }
    }
    
    private func toggleLike() {
        guard let userId = authService.currentUser?.id else { return }
        
        HapticManager.shared.lightImpact()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            likeScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                likeScale = 1.0
            }
        }
        
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        Task {
            do {
                if isLiked {
                    try await InteractionService.shared.likePost(userId: userId, postId: post.id)
                } else {
                    try await InteractionService.shared.unlikePost(userId: userId, postId: post.id)
                }
            } catch {
                isLiked.toggle()
                likeCount += isLiked ? 1 : -1
            }
        }
    }
    
    private func toggleBookmark() {
        guard let userId = authService.currentUser?.id else { return }
        
        HapticManager.shared.lightImpact()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            bookmarkRotation += 360
            bookmarkScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bookmarkScale = 1.0
            }
        }
        
        isBookmarked.toggle()
        
        Task {
            do {
                if isBookmarked {
                    try await InteractionService.shared.bookmarkPost(userId: userId, postId: post.id)
                } else {
                    try await InteractionService.shared.unbookmarkPost(userId: userId, postId: post.id)
                }
            } catch {
                isBookmarked.toggle()
            }
        }
    }
    
    private func checkLikeAndBookmarkStatus() {
        guard let userId = authService.currentUser?.id else { return }

        Task {
            do {
                isLiked = try await InteractionService.shared.isLiked(userId: userId, postId: post.id)
                isBookmarked = try await InteractionService.shared.isBookmarked(userId: userId, postId: post.id)
            } catch {
                print("🔴 [PostCard] checkStatus エラー: \(error)")
            }
        }
    }

    private func startDMFromPost() {
        guard let currentUserId = authService.currentUser?.id else { return }

        HapticManager.shared.lightImpact()

        Task {
            do {
                // DM制限チェック
                let canDM = try await MessageService.shared.checkDMPermission(senderId: currentUserId, receiverId: post.userId)
                if canDM {
                    await MainActor.run {
                        showDMSheet = true
                    }
                } else {
                    await MainActor.run {
                        dmErrorMessage = "この相手にはDMを送れません"
                        showDMErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    dmErrorMessage = "エラーが発生しました"
                    showDMErrorAlert = true
                }
            }
        }
    }
}

// MARK: - 投稿からDM送信シート
struct DMFromPostSheet: View {
    let post: Post
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var messageText = ""
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 投稿情報
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "quote.opening")
                            .foregroundColor(.purple)
                        Text("この投稿についてDM")
                            .font(.headline)
                    }

                    Text(post.centerNodeText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.leading, 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // 送信先
                HStack {
                    Text("送信先:")
                        .foregroundColor(.secondary)
                    Text("@\(post.user?.username ?? "unknown")")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.horizontal)

                // メッセージ入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("メッセージ")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextEditor(text: $messageText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("DMを送信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: sendDM) {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("送信")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func sendDM() {
        guard let currentUserId = authService.currentUser?.id else { return }
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmedMessage.isEmpty else { return }

        isSending = true

        Task {
            do {
                _ = try await MessageService.shared.startConversationFromPost(
                    currentUserId: currentUserId,
                    authorId: post.userId,
                    postId: post.id,
                    postTitle: post.centerNodeText,
                    initialMessage: trimmedMessage
                )
                HapticManager.shared.success()
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSending = false
                }
            }
        }
    }
}

// MARK: - 全画面マップView（名前変更で重複回避）
struct HomeFullMapView: View {
    let post: Post
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var showReasonPopup = false
    @State private var selectedReason = ""
    @State private var showComments = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                MindMapDisplayView(
                    post: post,
                    onShowReason: { reason in
                        selectedReason = reason
                        showReasonPopup = true
                    }
                )
                
                if showReasonPopup {
                    HomeReasonPopup(
                        reason: selectedReason,
                        onDismiss: { showReasonPopup = false }
                    )
                }
            }
            .navigationTitle(post.centerNodeText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showComments = true }) {
                        Image(systemName: "bubble.right")
                    }
                }
            }
            .sheet(isPresented: $showComments) {
                CommentsView(post: post)
                    .environmentObject(authService)
            }
        }
    }
}

// MARK: - 理由表示ポップアップ（HomeFeed専用）
struct HomeReasonPopup: View {
    let reason: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.purple)
                    Text("つながりの理由")
                        .font(.headline)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(reason)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }
}
