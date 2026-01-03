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
    
    // 他ユーザー用メニュー
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    @State private var showReportConfirmation = false
    
    init(post: Post) {
        self.post = post
        _likeCount = State(initialValue: post.likeCount)
    }
    
    private var isMyPost: Bool {
        post.userId == authService.currentUser?.id
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            MindMapDisplayView(
                post: post,
                onShowReason: { reason in
                    selectedReason = reason
                    showReasonPopup = true
                }
            )
            
            if showLikeAnimation {
                Image(systemName: "heart.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.pink)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 20) {
                        Button(action: toggleLike) {
                            VStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title)
                                    .foregroundColor(isLiked ? .pink : .primary)
                                Text("\(likeCount)")
                                    .font(.caption)
                            }
                        }
                        
                        Button(action: { showComments = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "bubble.right")
                                    .font(.title)
                                Text("\(post.commentCount)")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.primary)
                        
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
                        // 自分の投稿の場合
                        Button(role: .destructive, action: { showDeleteAlert = true }) {
                            Label("投稿を削除", systemImage: "trash")
                        }
                    } else {
                        // 他人の投稿の場合
                        Button(action: { showReportSheet = true }) {
                            Label("投稿を通報", systemImage: "exclamationmark.triangle")
                        }
                        
                        Button(role: .destructive, action: { showBlockAlert = true }) {
                            Label("このユーザーをブロック", systemImage: "hand.raised")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportPostSheet(post: post, onReport: {
                showReportConfirmation = true
            })
            .environmentObject(authService)
        }
        .alert("投稿を削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("この投稿を削除しますか？この操作は取り消せません。")
        }
        .alert("ユーザーをブロック", isPresented: $showBlockAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("ブロック", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("@\(post.user?.username ?? "unknown") をブロックしますか？\nこのユーザーの投稿が表示されなくなり、お互いにフォローが解除されます。")
        }
        .alert("通報しました", isPresented: $showReportConfirmation) {
            Button("OK") {}
        } message: {
            Text("ご報告ありがとうございます。内容を確認し、適切に対応いたします。")
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
    
    // MARK: - アクション
    
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
                
                // ✅ 投稿削除の通知を発火
                NotificationCenter.default.post(name: .postDeleted, object: nil)
                
                dismiss()
            } catch {
                print("削除失敗: \(error)")
            }
        }
    }
    
    private func blockUser() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            do {
                try await BlockReportService.shared.blockUser(
                    blockerId: currentUserId,
                    blockedId: post.userId
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("🔴 [PostDetail] ブロックエラー: \(error)")
            }
        }
    }
}

// MARK: - 通報シート
struct ReportPostSheet: View {
    let post: Post
    var onReport: () -> Void
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedReason: String = ""
    @State private var detailText: String = ""
    @State private var isSubmitting = false
    
    let reportReasons = [
        "スパム",
        "不適切なコンテンツ",
        "嫌がらせ・いじめ",
        "虚偽の情報",
        "著作権侵害",
        "その他"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("通報の理由") {
                    ForEach(reportReasons, id: \.self) { reason in
                        Button(action: { selectedReason = reason }) {
                            HStack {
                                Text(reason)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }
                
                Section("詳細（任意）") {
                    TextEditor(text: $detailText)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("投稿を通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("送信") {
                        submitReport()
                    }
                    .disabled(selectedReason.isEmpty || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func submitReport() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isSubmitting = true
        
        Task {
            do {
                try await BlockReportService.shared.reportPost(
                    reporterId: currentUserId,
                    reportedPostId: post.id,
                    reason: selectedReason,
                    detail: detailText.isEmpty ? nil : detailText
                )
                
                await MainActor.run {
                    dismiss()
                    onReport()
                }
            } catch {
                print("🔴 [ReportPost] 通報エラー: \(error)")
                await MainActor.run {
                    isSubmitting = false
                }
            }
        }
    }
}
