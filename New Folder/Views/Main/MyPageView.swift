// Views/Main/Profile/MyPageView.swift

import SwiftUI

struct MyPageView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = FeedViewModel()
    @State private var userPosts: [Post] = []
    @State private var bookmarkedPosts: [Post] = []
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var isLoading = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ProfileHeaderView(user: authService.currentUser)
                    
                    StatsView(
                        postsCount: userPosts.count,
                        branchesCount: authService.currentUser?.totalBranches ?? 0,
                        followersCount: followersCount,
                        followingCount: followingCount
                    )
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    Picker("投稿タイプ", selection: $selectedTab) {
                        Text("投稿").tag(0)
                        Text("ブックマーク").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if currentPosts.isEmpty {
                        EmptyPostsView()
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(sortedPosts) { post in
                                NavigationLink(destination: MyPostDetailView(post: post, onUpdate: { await loadData() })) {
                                    PostThumbnailView(post: post, showPinBadge: selectedTab == 0)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authService)
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .onChange(of: selectedTab) { _, _ in
                Task {
                    if selectedTab == 1 {
                        await loadBookmarks()
                    }
                }
            }
        }
    }
    
    private var currentPosts: [Post] {
        selectedTab == 0 ? userPosts : bookmarkedPosts
    }
    
    // ピン留め投稿を上に表示
    private var sortedPosts: [Post] {
        if selectedTab == 0 {
            return userPosts.sorted { $0.isPinned && !$1.isPinned }
        } else {
            return bookmarkedPosts
        }
    }
    
    private func loadData() async {
        guard let userId = authService.currentUser?.id else {
            print("🔴 [MyPage] currentUser が nil")
            return
        }
        
        print("🟡 [MyPage] loadData開始 - userId: \(userId)")
        isLoading = true
        
        userPosts = await viewModel.fetchUserPosts(userId: userId)
        print("✅ [MyPage] 投稿取得完了 - 件数: \(userPosts.count)")
        
        await loadFollowCounts(userId: userId)
        
        isLoading = false
    }
    
    private func loadFollowCounts(userId: UUID) async {
        print("🟡 [MyPage] フォロー数取得開始")
        
        do {
            let counts = try await InteractionService.shared.getFollowCounts(userId: userId)
            followersCount = counts.followers
            followingCount = counts.following
            print("✅ [MyPage] フォロー数取得完了 - フォロワー: \(followersCount), フォロー中: \(followingCount)")
        } catch {
            print("🔴 [MyPage] フォロー数取得エラー: \(error)")
        }
    }
    
    private func loadBookmarks() async {
        guard let userId = authService.currentUser?.id else { return }
        
        print("🟡 [MyPage] ブックマーク取得開始")
        
        do {
            bookmarkedPosts = try await InteractionService.shared.fetchBookmarks(userId: userId)
            print("✅ [MyPage] ブックマーク取得完了 - 件数: \(bookmarkedPosts.count)")
        } catch {
            print("🔴 [MyPage] ブックマーク取得エラー: \(error)")
        }
    }
}

// MARK: - プロフィールヘッダー
struct ProfileHeaderView: View {
    let user: User?
    
    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String(user?.displayName.prefix(1) ?? "?"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
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

// MARK: - 統計View
struct StatsView: View {
    let postsCount: Int
    let branchesCount: Int
    let followersCount: Int
    let followingCount: Int
    
    var body: some View {
        HStack(spacing: 32) {
            StatItem(value: postsCount, label: "投稿")
            StatItem(value: branchesCount, label: "枝")
            StatItem(value: followersCount, label: "フォロワー")
            StatItem(value: followingCount, label: "フォロー中")
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
