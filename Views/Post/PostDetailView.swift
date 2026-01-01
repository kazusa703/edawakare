// Views/Post/PostDetailView.swift

import SwiftUI

struct PostDetailView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    let post: Post
    @State private var showComments = false
    @State private var showDeleteAlert = false
    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var showLikeAnimation = false
    @State private var selectedConnection: NodeConnection?
    @State private var likeCount: Int
    @State private var showReasonPopup = false
    @State private var selectedReason = ""
    
    init(post: Post) {
        self.post = post
        _likeCount = State(initialValue: post.likeCount)
    }
    
    // MockData ではなく authService を使用
    private var isMyPost: Bool {
        post.userId == authService.currentUser?.id
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            // マインドマップ表示部分
            MindMapDisplayView(
                post: post,
                onShowReason: { reason in
                    selectedReason = reason
                    showReasonPopup = true
                }
            )
            
            // いいねアニメーション
            if showLikeAnimation {
                Image(systemName: "heart.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.pink)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
            }
            
            // 右側のアクションボタン
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 20) {
                        // いいねボタン
                        Button(action: toggleLike) {
                            VStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title)
                                    .foregroundColor(isLiked ? .pink : .primary)
                                Text("\(likeCount)")
                                    .font(.caption)
                            }
                        }
                        
                        // コメントボタン
                        Button(action: { showComments = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "bubble.right")
                                    .font(.title)
                                Text("\(post.commentCount)")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.primary)
                        
                        // ブックマークボタン
                        Button(action: toggleBookmark) {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.title)
                                .foregroundColor(isBookmarked ? .purple : .primary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.7))
                    .cornerRadius(30)
                    .padding(.trailing, 16)
                    .padding(.bottom, 50)
                }
            }
            
            // 理由表示ポップアップ（HomeFeedViewと共通のコンポーネントを使用）
            if showReasonPopup {
                ReasonDisplayPopup(
                    reason: selectedReason,
                    onDismiss: { showReasonPopup = false }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(post.centerNodeText)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if isMyPost {
                        Button(role: .destructive, action: { showDeleteAlert = true }) {
                            Label("投稿を削除", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive, action: {}) { Label("通報", systemImage: "exclamationmark.triangle") }
                        Button(role: .destructive, action: {}) { Label("ブロック", systemImage: "hand.raised") }
                    }
                } label: { Image(systemName: "ellipsis") }
            }
        }
        // CommentsView(post: post) に修正（引数名と型を合わせる）
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
        }
        .alert("投稿を削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("この投稿を削除しますか？この操作は取り消せません。")
        }
        .onAppear {
            checkInteractionStatus()
        }
        .onTapGesture(count: 2) {
            if !isLiked { toggleLike() }
            showLikeAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showLikeAnimation = false
            }
        }
    }
    
    // --- アクション ---
    
    private func toggleLike() {
        guard let userId = authService.currentUser?.id else { return }
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
    
    private func checkInteractionStatus() {
        guard let userId = authService.currentUser?.id else { return }
        Task {
            isLiked = (try? await InteractionService.shared.isLiked(userId: userId, postId: post.id)) ?? false
            isBookmarked = (try? await InteractionService.shared.isBookmarked(userId: userId, postId: post.id)) ?? false
        }
    }
    
    private func deletePost() {
        Task {
            do {
                try await PostService.shared.deletePost(postId: post.id)
                dismiss()
            } catch {
                print("削除失敗: \(error)")
            }
        }
    }
}
