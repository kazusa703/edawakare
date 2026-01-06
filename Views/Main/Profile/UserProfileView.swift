// Views/Main/Profile/UserProfileView.swift

import SwiftUI
import Supabase

struct UserProfileView: View {
    let userId: UUID
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var profile: UserProfileData?
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var isCurrentUser = false
    @State private var followerCount = 0
    @State private var followingCount = 0
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showUnfollowAlert = false
    @State private var selectedPostIndex: Int?
    @State private var navigateToChat = false
    @State private var chatConversation: Conversation?
    @State private var showDMErrorAlert = false
    @State private var dmErrorMessage = ""
    @State private var isMutualFollow = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if let profile = profile {
                    // プロフィールヘッダー
                    VStack(spacing: 16) {
                        // アイコン（相互フォロー縁色対応）
                        ZStack {
                            // 相互フォロー時の縁色
                            if isMutualFollow, let colorHex = profile.iconBorderColor {
                                Circle()
                                    .stroke(Color(hex: colorHex) ?? .purple, lineWidth: 4)
                                    .frame(width: 108, height: 108)
                            }

                            if let iconUrl = profile.iconUrl, let url = URL(string: iconUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(String(profile.displayName?.prefix(1) ?? "?"))
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        
                        // 名前とユーザー名
                        VStack(spacing: 4) {
                            Text(profile.displayName ?? "名前未設定")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("@\(profile.username ?? "unknown")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // 自己紹介
                        if let bio = profile.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        
                        // フォロー数
                        HStack(spacing: 32) {
                            Button(action: { showFollowers = true }) {
                                VStack {
                                    Text("\(followerCount)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Text("フォロワー")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: { showFollowing = true }) {
                                VStack {
                                    Text("\(followingCount)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Text("フォロー中")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // フォローボタンとDMボタン（自分以外の場合）
                        if !isCurrentUser {
                            HStack(spacing: 12) {
                                Button(action: {
                                    if isFollowing {
                                        showUnfollowAlert = true
                                    } else {
                                        toggleFollow()
                                    }
                                }) {
                                    Text(isFollowing ? "フォロー中" : "フォローする")
                                        .fontWeight(.semibold)
                                        .frame(width: 120)
                                        .padding(.vertical, 10)
                                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.purple)
                                        .foregroundColor(isFollowing ? .primary : .white)
                                        .cornerRadius(20)
                                }

                                Button(action: startDMConversation) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 16))
                                        .frame(width: 44, height: 44)
                                        .background(Color.purple.opacity(0.1))
                                        .foregroundColor(.purple)
                                        .cornerRadius(22)
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    Divider()
                        .padding(.vertical)
                    
                    // 投稿一覧
                    if posts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("まだ投稿がありません")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                                Button {
                                    selectedPostIndex = index
                                } label: {
                                    ProfilePostCard(post: post)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFollowers) {
            FollowListView(userId: userId, listType: .followers)
        }
        .sheet(isPresented: $showFollowing) {
            FollowListView(userId: userId, listType: .following)
        }
        .fullScreenCover(item: $selectedPostIndex) { index in
            UserPostsFeedView(posts: posts, initialIndex: index)
                .environmentObject(authService)
        }
        .navigationDestination(isPresented: $navigateToChat) {
            if let conversation = chatConversation {
                ChatView(conversation: conversation)
                    .environmentObject(authService)
            }
        }
        .alert("フォロー解除", isPresented: $showUnfollowAlert) {
            Button("解除", role: .destructive) {
                toggleFollow()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(profile?.displayName ?? "このユーザー")のフォローを解除しますか？")
        }
        .alert("DM送信不可", isPresented: $showDMErrorAlert) {
            Button("OK") {}
        } message: {
            Text(dmErrorMessage)
        }
        .task {
            await loadUserData()
        }
    }

    private func startDMConversation() {
        Task {
            guard let myId = authService.currentUser?.id else { return }
            do {
                let conversation = try await MessageService.shared.createConversation(user1Id: myId, user2Id: userId)
                await MainActor.run {
                    chatConversation = conversation
                    navigateToChat = true
                }
            } catch let error as DMError {
                await MainActor.run {
                    dmErrorMessage = error.localizedDescription
                    showDMErrorAlert = true
                }
            } catch {
                await MainActor.run {
                    dmErrorMessage = "DMの作成に失敗しました"
                    showDMErrorAlert = true
                }
            }
        }
    }
    
    private func loadUserData() async {
        isLoading = true
        
        do {
            // 現在のユーザーかチェック
            let session = try await SupabaseClient.shared.client.auth.session
            isCurrentUser = session.user.id == userId
            
            // プロフィール取得（usersテーブルを使用）
            let users: [UserProfileData] = try await SupabaseClient.shared.client
                .from("users")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            
            profile = users.first
            
            // 投稿取得
            posts = try await PostService.shared.fetchUserPosts(userId: userId)
            
            // フォロー数取得
            let followersResult: [FollowData] = try await SupabaseClient.shared.client
                .from("follows")
                .select()
                .eq("following_id", value: userId.uuidString)
                .execute()
                .value
            followerCount = followersResult.count
            
            let followingResult: [FollowData] = try await SupabaseClient.shared.client
                .from("follows")
                .select()
                .eq("follower_id", value: userId.uuidString)
                .execute()
                .value
            followingCount = followingResult.count
            
            // フォロー状態チェック
            if !isCurrentUser {
                let followCheck: [FollowData] = try await SupabaseClient.shared.client
                    .from("follows")
                    .select()
                    .eq("follower_id", value: session.user.id.uuidString)
                    .eq("following_id", value: userId.uuidString)
                    .execute()
                    .value
                isFollowing = !followCheck.isEmpty

                // 相互フォロー判定
                let mutual = try await InteractionService.shared.isMutualFollow(userId1: session.user.id, userId2: userId)
                isMutualFollow = mutual
            }

        } catch {
            print("Error loading user data: \(error)")
        }

        isLoading = false
    }
    
    private func toggleFollow() {
        Task {
            do {
                let session = try await SupabaseClient.shared.client.auth.session
                let currentUserId = session.user.id
                
                if isFollowing {
                    // アンフォロー
                    try await SupabaseClient.shared.client
                        .from("follows")
                        .delete()
                        .eq("follower_id", value: currentUserId.uuidString)
                        .eq("following_id", value: userId.uuidString)
                        .execute()
                    
                    isFollowing = false
                    followerCount -= 1
                } else {
                    // フォロー
                    let follow: [String: String] = [
                        "follower_id": currentUserId.uuidString,
                        "following_id": userId.uuidString
                    ]
                    
                    try await SupabaseClient.shared.client
                        .from("follows")
                        .insert(follow)
                        .execute()
                    
                    isFollowing = true
                    followerCount += 1
                    
                    // 通知を直接作成
                    let notification: [String: String] = [
                        "recipient_id": userId.uuidString,
                        "sender_id": currentUserId.uuidString,
                        "type": "follow"
                    ]
                    try? await SupabaseClient.shared.client
                        .from("notifications")
                        .insert(notification)
                        .execute()
                }
                
            } catch {
                print("Error toggling follow: \(error)")
            }
        }
    }
}

// MARK: - プロフィール用投稿カード
struct ProfilePostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // テーマ
            HStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.centerNodeText)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(formatDate(post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // ノード数と接続数
            HStack(spacing: 16) {
                Label("\(post.nodes?.count ?? 0) ノード", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(post.connections?.count ?? 0) 接続", systemImage: "link")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - このファイル専用のデータモデル
struct UserProfileData: Codable {
    let id: UUID
    let username: String?
    let displayName: String?
    let bio: String?
    let iconUrl: String?
    let iconBorderColor: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case iconUrl = "icon_url"
        case iconBorderColor = "icon_border_color"
    }
}

struct FollowData: Codable {
    let id: UUID?
    let followerId: UUID
    let followingId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
    }
}

// MARK: - Int Identifiable for fullScreenCover
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - ユーザー投稿フィード（縦スワイプ）
struct UserPostsFeedView: View {
    let posts: [Post]
    let initialIndex: Int
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground).ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    UserPostCardView(post: post)
                        .environmentObject(authService)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            // 閉じるボタン
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .onAppear {
            currentIndex = initialIndex
        }
    }
}

// MARK: - ユーザー投稿カードView
struct UserPostCardView: View {
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
    @State private var bookmarkScale: CGFloat = 1.0

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
                    isFixedDisplay: true
                )
                .frame(width: geometry.size.width, height: geometry.size.height * 0.7)
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)

                if showLikeAnimation {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.pink)
                        .transition(.scale.combined(with: .opacity))
                }

                // 右側のアクションボタン
                VStack(spacing: 20) {
                    Spacer()

                    NavigationLink(destination: UserProfileView(userId: post.userId)) {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(post.user?.displayName.prefix(1) ?? "?"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                    }

                    Button(action: { toggleLike() }) {
                        VStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.title)
                                .foregroundColor(isLiked ? .pink : .primary)
                                .scaleEffect(likeScale)
                            Text("\(likeCount)")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }

                    Button(action: { showComments = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .font(.title)
                            Text("\(post.commentCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
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

                // 下部の投稿情報
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
                    UserPostReasonPopup(
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
                        withAnimation { showLikeAnimation = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
                .environmentObject(authService)
        }
        .fullScreenCover(isPresented: $showFullMap) {
            UserPostFullMapView(post: post)
                .environmentObject(authService)
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

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
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
                print("🔴 [UserPostCard] checkStatus エラー: \(error)")
            }
        }
    }
}

// MARK: - 全画面マップView
struct UserPostFullMapView: View {
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
                    UserPostReasonPopup(
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

// MARK: - 理由表示ポップアップ
struct UserPostReasonPopup: View {
    let reason: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

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
