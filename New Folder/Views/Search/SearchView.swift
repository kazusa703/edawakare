// Views/Main/Search/SearchView.swift

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var authService: AuthService
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var postResults: [Post] = []
    @State private var userResults: [User] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    
    // トレンド・おすすめデータ
    @State private var popularNodes: [String] = []
    @State private var recommendedUsers: [User] = []
    @State private var isLoadingTrends = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                SearchBarView(
                    searchText: $searchText,
                    onSubmit: performSearch,
                    onClear: clearSearch
                )
                
                // タブ切り替え（検索後のみ表示）
                if hasSearched {
                    Picker("検索対象", selection: $selectedTab) {
                        Text("投稿").tag(0)
                        Text("ユーザー").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                // コンテンツ
                if isSearching {
                    Spacer()
                    ProgressView("検索中...")
                    Spacer()
                } else if !hasSearched {
                    // 検索前: トレンド & おすすめ表示
                    DiscoverView(
                        popularNodes: popularNodes,
                        recommendedUsers: recommendedUsers,
                        isLoading: isLoadingTrends,
                        onNodeTap: { node in
                            searchText = node
                            performSearch()
                        }
                    )
                    .environmentObject(authService)
                } else if selectedTab == 0 {
                    // 投稿検索結果
                    PostSearchResultsView(posts: postResults)
                        .environmentObject(authService)
                } else {
                    // ユーザー検索結果
                    UserSearchResultsView(users: userResults)
                        .environmentObject(authService)
                }
            }
            .navigationTitle("検索")
            .task {
                await loadTrendsAndRecommendations()
            }
        }
    }
    
    // MARK: - 検索実行
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        
        print("🔍 [SearchView] 検索開始: '\(query)'")
        isSearching = true
        hasSearched = true
        
        Task {
            do {
                async let postsTask = PostService.shared.searchByNodeText(query: query)
                async let usersTask = UserService.shared.searchUsers(query: query)
                
                let (posts, users) = try await (postsTask, usersTask)
                
                await MainActor.run {
                    postResults = posts
                    userResults = users
                    isSearching = false
                }
                
                print("✅ [SearchView] 検索完了 - 投稿: \(posts.count), ユーザー: \(users.count)")
            } catch {
                print("🔴 [SearchView] 検索エラー: \(error)")
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }
    
    // MARK: - 検索クリア
    private func clearSearch() {
        searchText = ""
        postResults = []
        userResults = []
        hasSearched = false
    }
    
    // MARK: - トレンド & おすすめ読み込み
    private func loadTrendsAndRecommendations() async {
        isLoadingTrends = true
        
        do {
            async let nodesTask = PostService.shared.fetchPopularNodes(limit: 8)
            async let usersTask = UserService.shared.fetchRecommendedUsers(
                currentUserId: authService.currentUser?.id,
                limit: 5
            )
            
            let (nodes, users) = try await (nodesTask, usersTask)
            
            await MainActor.run {
                popularNodes = nodes
                recommendedUsers = users
                isLoadingTrends = false
            }
        } catch {
            print("🔴 [SearchView] トレンド読み込みエラー: \(error)")
            await MainActor.run {
                isLoadingTrends = false
            }
        }
    }
}

// MARK: - 検索バー
struct SearchBarView: View {
    @Binding var searchText: String
    var onSubmit: () -> Void
    var onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("テーマやユーザーを検索...", text: $searchText)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onSubmit(onSubmit)
                
                if !searchText.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            if !searchText.isEmpty {
                Button("検索", action: onSubmit)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - 発見画面（検索前）
struct DiscoverView: View {
    let popularNodes: [String]
    let recommendedUsers: [User]
    let isLoading: Bool
    var onNodeTap: (String) -> Void
    
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 人気のノード
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("人気のノード")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    } else if popularNodes.isEmpty {
                        Text("まだ人気のノードがありません")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(popularNodes, id: \.self) { node in
                                    PopularNodeChip(text: node) {
                                        onNodeTap(node)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // おすすめユーザー
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.purple)
                        Text("おすすめユーザー")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    } else if recommendedUsers.isEmpty {
                        Text("おすすめユーザーがいません")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(recommendedUsers) { user in
                                RecommendedUserRow(user: user)
                                    .environmentObject(authService)
                                
                                if user.id != recommendedUsers.last?.id {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // 検索ヒント
                VStack(spacing: 16) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("興味を検索してみましょう")
                        .font(.headline)
                    
                    Text("好きな作品やテーマを検索して\n新しい枝分かれを発見しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 人気ノードチップ
struct PopularNodeChip: View {
    let text: String
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 8, height: 8)
                
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - おすすめユーザー行
struct RecommendedUserRow: View {
    let user: User
    @EnvironmentObject var authService: AuthService
    @State private var isFollowing = false
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            // アバター
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(user.displayName.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            
            // ユーザー情報
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // フォローボタン
            Button(action: toggleFollow) {
                if isLoading {
                    ProgressView()
                        .frame(width: 80, height: 32)
                } else {
                    Text(isFollowing ? "フォロー中" : "フォロー")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isFollowing ? .secondary : .white)
                        .frame(width: 80, height: 32)
                        .background(isFollowing ? Color(.secondarySystemBackground) : Color.purple)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isFollowing ? Color.secondary.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                }
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .task {
            await checkFollowStatus()
        }
    }
    
    private func checkFollowStatus() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            isFollowing = try await InteractionService.shared.isFollowing(
                followerId: currentUserId,
                followingId: user.id
            )
        } catch {
            print("🔴 [RecommendedUserRow] フォロー状態確認エラー: \(error)")
        }
    }
    
    private func toggleFollow() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                if isFollowing {
                    try await InteractionService.shared.unfollow(
                        followerId: currentUserId,
                        followingId: user.id
                    )
                } else {
                    try await InteractionService.shared.follow(
                        followerId: currentUserId,
                        followingId: user.id
                    )
                }
                
                await MainActor.run {
                    isFollowing.toggle()
                    isLoading = false
                }
            } catch {
                print("🔴 [RecommendedUserRow] フォロー操作エラー: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 投稿検索結果
struct PostSearchResultsView: View {
    let posts: [Post]
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if posts.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("投稿が見つかりませんでした")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("別のキーワードで検索してみてください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(posts) { post in
                            NavigationLink(destination: PostDetailView(post: post).environmentObject(authService)) {
                                SearchPostCardView(post: post)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - 検索投稿カード
struct SearchPostCardView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ユーザー情報
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(post.user?.displayName.prefix(1) ?? "?"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(post.user?.displayName ?? "ユーザー")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("@\(post.user?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // ノード数バッジ
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption2)
                    Text("\(post.nodes?.count ?? 0)")
                        .font(.caption)
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 中心ノード
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 12, height: 12)
                
                Text(post.centerNodeText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            // 子ノードプレビュー（最大3つ）
            if let childNodes = post.nodes?.filter({ !$0.isCenter }).prefix(3), !childNodes.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(childNodes)) { node in
                        Text(node.text)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(12)
                            .lineLimit(1)
                    }
                    
                    if let totalNodes = post.nodes?.filter({ !$0.isCenter }).count, totalNodes > 3 {
                        Text("+\(totalNodes - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(12)
                    }
                }
            }
            
            // 統計
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.caption)
                    Text("\(post.likeCount)")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.caption)
                    Text("\(post.commentCount)")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - ユーザー検索結果
struct UserSearchResultsView: View {
    let users: [User]
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if users.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("ユーザーが見つかりませんでした")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("別のキーワードで検索してみてください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(users) { user in
                            SearchUserRowView(user: user)
                                .environmentObject(authService)
                            
                            if user.id != users.last?.id {
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
    }
}

// MARK: - 検索ユーザー行
struct SearchUserRowView: View {
    let user: User
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationLink(destination: UserProfileView(userId: user.id)) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(user.displayName.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(user.totalBranches)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Text("枝")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - FlowLayout（横並びで折り返し）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            height = y + lineHeight
        }
    }
}
