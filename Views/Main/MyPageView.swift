// Views/Main/Profile/MyPageView.swift

import SwiftUI

struct MyPageView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = FeedViewModel()
    @State private var userPosts: [Post] = []
    @State private var showSettings = false
    @State private var showCreatePost = false  // 追加
    @State private var isLoading = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var hasLoaded = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ProfileHeaderView(user: authService.currentUser)
                    
                    StatsView(
                        postsCount: userPosts.count,
                        branchesCount: authService.currentUser?.totalBranches ?? 0,
                        followersCount: followersCount,
                        followingCount: followingCount,
                        userId: authService.currentUser?.id
                    )
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    HStack {
                        Text("投稿")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    if isLoading {
                        // スケルトンローディング
                        MyPagePostsSkeleton()
                    } else if userPosts.isEmpty {
                        EmptyPostsView()
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(sortedPosts) { post in
                                NavigationLink(destination: MyPostDetailView(post: post, onUpdate: { await loadData() })) {
                                    PostThumbnailView(post: post, showPinBadge: true)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左側: 投稿作成ボタン
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCreatePost = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                
                // 右側: 設定ボタン
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCreatePost) {
                CreatePostView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                Task {
                    await loadData()
                }
            }) {
                SettingsView()
                    .environmentObject(authService)
            }
            .onAppear {
                if !hasLoaded {
                    hasLoaded = true
                    Task {
                        await loadData()
                    }
                }
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    private var sortedPosts: [Post] {
        userPosts.sorted { $0.isPinned && !$1.isPinned }
    }
    
    private func loadData() async {
        guard let userId = authService.currentUser?.id else {
            print("🔴 [MyPage] currentUser が nil")
            return
        }
        
        print("🟡 [MyPage] loadData開始 - userId: \(userId)")
        
        await MainActor.run {
            isLoading = true
        }
        
        async let postsTask = viewModel.fetchUserPosts(userId: userId)
        async let countsTask = fetchFollowCounts(userId: userId)
        
        let posts = await postsTask
        let counts = await countsTask
        
        await MainActor.run {
            userPosts = posts
            followersCount = counts.followers
            followingCount = counts.following
            isLoading = false
        }
        
        print("✅ [MyPage] 投稿取得完了 - 件数: \(posts.count)")
    }
    
    private func fetchFollowCounts(userId: UUID) async -> (followers: Int, following: Int) {
        print("🟡 [MyPage] フォロー数取得開始")
        
        do {
            let counts = try await InteractionService.shared.getFollowCounts(userId: userId)
            print("✅ [MyPage] フォロー数取得完了 - フォロワー: \(counts.followers), フォロー中: \(counts.following)")
            return counts
        } catch {
            print("🔴 [MyPage] フォロー数取得エラー: \(error)")
            return (0, 0)
        }
    }
}

// MARK: - マイページ投稿スケルトン
struct MyPagePostsSkeleton: View {
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                PostThumbnailSkeleton()
            }
        }
        .padding()
    }
}

// MARK: - 投稿サムネイルスケルトン
struct PostThumbnailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SkeletonCircle(size: 12)
                SkeletonBox(width: 150, height: 18)
                Spacer()
                SkeletonBox(width: 60, height: 14)
            }
            
            HStack(spacing: 16) {
                SkeletonBox(width: 40, height: 14)
                SkeletonBox(width: 40, height: 14)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - プロフィールヘッダー（アバター対応版）
struct ProfileHeaderView: View {
    let user: User?
    
    var body: some View {
        VStack(spacing: 12) {
            ProfileAvatarView(user: user, size: 80)
            
            Text(user?.displayName ?? "ユーザー")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("@\(user?.username ?? "unknown")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - 統計View（タップ可能版）
struct StatsView: View {
    let postsCount: Int
    let branchesCount: Int
    let followersCount: Int
    let followingCount: Int
    let userId: UUID?
    
    @State private var showFollowers = false
    @State private var showFollowing = false
    
    var body: some View {
        HStack(spacing: 32) {
            StatItem(value: postsCount, label: "投稿")
            StatItem(value: branchesCount, label: "枝")
            
            Button(action: { showFollowers = true }) {
                VStack(spacing: 4) {
                    Text("\(followersCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("フォロワー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            Button(action: { showFollowing = true }) {
                VStack(spacing: 4) {
                    Text("\(followingCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("フォロー中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .sheet(isPresented: $showFollowers) {
            if let userId = userId {
                FollowListView(userId: userId, listType: .followers)
            }
        }
        .sheet(isPresented: $showFollowing) {
            if let userId = userId {
                FollowListView(userId: userId, listType: .following)
            }
        }
    }
}

struct StatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 空の投稿View
struct EmptyPostsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 50))
                .foregroundColor(.purple.opacity(0.5))
            
            Text("まだ投稿がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("最初の枝分かれを作成しましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
}

// MARK: - 投稿サムネイル
struct PostThumbnailView: View {
    let post: Post
    var showPinBadge: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if showPinBadge && post.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 12, height: 12)
                
                Text(post.centerNodeText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                if post.visibility == "followers_only" {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(post.nodes?.count ?? 0) ノード")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Label("\(post.likeCount)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.right")
                
                if !post.commentsEnabled {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .overlay(
                            Image(systemName: "line.diagonal")
                                .font(.caption2)
                                .foregroundColor(.red)
                        )
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
