// Views/Main/Home/HomeFeedView.swift

import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedTab = 0
    @State private var showCreatePost = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("フィード", selection: $selectedTab) {
                    Text("おすすめ").tag(0)
                    Text("フォロー中").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    // スケルトンローディング
                    HomeFeedSkeleton()
                } else if currentPosts.isEmpty {
                    EmptyFeedView(selectedTab: selectedTab)
                } else {
                    TabView {
                        ForEach(currentPosts) { post in
                            PostCardView(post: post)
                                .environmentObject(authService)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("枝分かれ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.lightImpact()  // ハプティック追加
                        showCreatePost = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
                    .environmentObject(authService)
                    .onDisappear {
                        Task {
                            await loadPosts()
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
                print("📬 [HomeFeedView] 新規投稿通知を受信")
                Task {
                    await viewModel.fetchPosts()
                    if let userId = authService.currentUser?.id {
                        await viewModel.fetchFollowingPosts(userId: userId)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .postDeleted)) { _ in
                print("📬 [HomeFeedView] 投稿削除通知を受信")
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
        print("🟡 [HomeFeed] loadPosts開始 - selectedTab: \(selectedTab)")
        
        if selectedTab == 0 {
            await viewModel.fetchPosts()
        } else {
            if let userId = authService.currentUser?.id {
                await viewModel.fetchFollowingPosts(userId: userId)
            }
        }
        
        print("✅ [HomeFeed] loadPosts完了 - 件数: \(currentPosts.count)")
    }
}

// MARK: - 空のフィードView
struct EmptyFeedView: View {
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

// MARK: - 投稿カードView
struct PostCardView: View {
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
    
    // いいねアニメーション用
    @State private var likeScale: CGFloat = 1.0
    
    // ブックマークアニメーション用
    @State private var bookmarkRotation: Double = 0
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
                    }
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
                        Circle()
                            .fill(
                                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(post.user?.displayName.prefix(1) ?? "?"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // いいねボタン（アニメーション付き）
                    Button(action: toggleLike) {
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
                    
                    // ブックマークボタン（アニメーション付き）
                    Button(action: toggleBookmark) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.title)
                            .foregroundColor(isBookmarked ? .purple : .primary)
                            .scaleEffect(bookmarkScale)
                            .rotationEffect(.degrees(bookmarkRotation))
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
                    ReasonDisplayPopup(
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
        .fullScreenCover(isPresented: $showFullMap) {
            FullMapView(post: post)
                .environmentObject(authService)
        }
        .onAppear {
            likeCount = post.likeCount
            checkLikeAndBookmarkStatus()
        }
    }
    
    private func toggleLike() {
        guard let userId = authService.currentUser?.id else { return }
        
        // ハプティック
        HapticManager.shared.lightImpact()
        
        // スケールバウンスアニメーション
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
        
        // ハプティック
        HapticManager.shared.lightImpact()
        
        // 回転＋スケールアニメーション
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
}

// MARK: - 全画面マップView
struct FullMapView: View {
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
                    ReasonDisplayPopup(
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

// MARK: - マインドマップ表示View（閲覧用）
struct MindMapDisplayView: View {
    let post: Post
    var onShowReason: (String) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(post.connections ?? []) { connection in
                    ConnectionDisplayLine(
                        connection: connection,
                        nodes: post.nodes ?? [],
                        onShowReason: onShowReason
                    )
                }
                
                ForEach(post.nodes ?? []) { node in
                    NodeDisplayView(node: node, centerText: post.centerNodeText)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, 0.5), 2.5)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
        }
    }
}

// MARK: - ノード表示View
struct NodeDisplayView: View {
    let node: Node
    let centerText: String
    
    var nodeSize: CGFloat {
        node.isCenter ? 100 : 80
    }
    
    var displayText: String {
        node.isCenter ? centerText : node.text
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    node.isCenter
                        ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            if !node.isCenter {
                Circle()
                    .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                    .frame(width: nodeSize, height: nodeSize)
            }
            
            Text(displayText)
                .font(.system(size: node.isCenter ? 14 : 12))
                .fontWeight(node.isCenter ? .bold : .medium)
                .foregroundColor(node.isCenter ? .white : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(width: nodeSize - 16)
        }
        .position(x: node.positionX, y: node.positionY)
    }
}

// MARK: - 接続線表示View
struct ConnectionDisplayLine: View {
    let connection: NodeConnection
    let nodes: [Node]
    var onShowReason: (String) -> Void
    
    var body: some View {
        if let fromNode = nodes.first(where: { $0.id == connection.fromNodeId }),
           let toNode = nodes.first(where: { $0.id == connection.toNodeId }) {
            
            let fromPoint = CGPoint(x: fromNode.positionX, y: fromNode.positionY)
            let toPoint = CGPoint(x: toNode.positionX, y: toNode.positionY)
            
            let fromRadius: CGFloat = fromNode.isCenter ? 50 : 40
            let toRadius: CGFloat = toNode.isCenter ? 50 : 40
            
            let angle = atan2(toPoint.y - fromPoint.y, toPoint.x - fromPoint.x)
            let adjustedFromPoint = CGPoint(
                x: fromPoint.x + cos(angle) * fromRadius,
                y: fromPoint.y + sin(angle) * fromRadius
            )
            let adjustedToPoint = CGPoint(
                x: toPoint.x - cos(angle) * toRadius,
                y: toPoint.y - sin(angle) * toRadius
            )
            
            let midPoint = CGPoint(
                x: (adjustedFromPoint.x + adjustedToPoint.x) / 2,
                y: (adjustedFromPoint.y + adjustedToPoint.y) / 2
            )
            
            ZStack {
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .stroke(Color.purple.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                Path { path in
                    let arrowAngle: CGFloat = .pi / 6
                    let arrowSize: CGFloat = 12
                    
                    let point1 = CGPoint(
                        x: adjustedToPoint.x - arrowSize * cos(angle - arrowAngle),
                        y: adjustedToPoint.y - arrowSize * sin(angle - arrowAngle)
                    )
                    let point2 = CGPoint(
                        x: adjustedToPoint.x - arrowSize * cos(angle + arrowAngle),
                        y: adjustedToPoint.y - arrowSize * sin(angle + arrowAngle)
                    )
                    
                    path.move(to: adjustedToPoint)
                    path.addLine(to: point1)
                    path.move(to: adjustedToPoint)
                    path.addLine(to: point2)
                }
                .stroke(Color.purple.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                if let reason = connection.reason, !reason.isEmpty {
                    Button(action: { onShowReason(reason) }) {
                        ZStack {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                    .position(midPoint)
                }
            }
        }
    }
}

// MARK: - 理由表示ポップアップ
struct ReasonDisplayPopup: View {
    let reason: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 16) {
                HStack {
                    Text("つながりの理由")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(reason)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
            .padding(.horizontal, 32)
        }
    }
}
