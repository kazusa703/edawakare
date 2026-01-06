// Views/Post/CommentsView.swift

import SwiftUI

struct CommentsView: View {
    let post: Post
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var replyingTo: Comment? = nil
    @State private var sortBy: String = "recent"  // "recent" or "popular"

    var postOwnerId: UUID {
        post.userId
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ソート切替Picker
                Picker("並び替え", selection: $sortBy) {
                    Text("新着順").tag("recent")
                    Text("人気順").tag("popular")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onChange(of: sortBy) { _, _ in
                    Task {
                        await loadComments()
                    }
                }

                Divider()

                if isLoading && comments.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if comments.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundColor(.purple.opacity(0.5))
                        Text("まだコメントがありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("最初のコメントを投稿しましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(rootComments) { comment in
                            CommentThreadView(
                                comment: comment,
                                allComments: comments,
                                postOwnerId: postOwnerId,
                                currentUserId: authService.currentUser?.id,
                                onReply: { replyingTo = $0 },
                                onDelete: { deleteComment($0) },
                                onLikeToggle: { toggleLike(for: $0) }
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }

                Divider()

                if let replying = replyingTo {
                    HStack {
                        Text("@\(replying.user?.username ?? "unknown") に返信中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { replyingTo = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    TextField(replyingTo != nil ? "返信を入力..." : "コメントを入力...", text: $newCommentText)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)

                    Button(action: sendComment) {
                        if isSending {
                            ProgressView()
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(
                                    newCommentText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? .gray
                                    : .purple
                                )
                        }
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("コメント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await loadComments()
            }
        }
    }

    private var rootComments: [Comment] {
        comments.filter { $0.parentCommentId == nil }
    }

    private func loadComments() async {
        isLoading = true
        do {
            comments = try await CommentService.shared.fetchComments(postId: post.id, sortBy: sortBy)
        } catch {
            print("🔴 [CommentsView] loadComments error: \(error)")
        }
        isLoading = false
    }

    private func sendComment() {
        guard let userId = authService.currentUser?.id else { return }
        let text = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        isSending = true

        Task {
            do {
                let newComment: Comment
                if let parentComment = replyingTo {
                    // 返信の場合
                    newComment = try await CommentService.shared.replyToComment(
                        postId: post.id,
                        parentId: parentComment.id,
                        userId: userId,
                        content: text
                    )
                } else {
                    // 通常コメントの場合
                    newComment = try await InteractionService.shared.addComment(
                        userId: userId,
                        postId: post.id,
                        content: text,
                        parentCommentId: nil
                    )
                }

                await MainActor.run {
                    comments.append(newComment)
                    newCommentText = ""
                    replyingTo = nil
                    isSending = false
                }
            } catch {
                print("🔴 [CommentsView] sendComment error: \(error)")
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }

    private func deleteComment(_ comment: Comment) {
        Task {
            do {
                try await InteractionService.shared.deleteComment(commentId: comment.id)
                await MainActor.run {
                    comments.removeAll { $0.id == comment.id || $0.parentCommentId == comment.id }
                }
            } catch {
                print("🔴 [CommentsView] deleteComment error: \(error)")
            }
        }
    }

    private func toggleLike(for comment: Comment) {
        guard let userId = authService.currentUser?.id else { return }
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        Task {
            do {
                let isLiked = try await CommentService.shared.isCommentLiked(commentId: comment.id, userId: userId)

                if isLiked {
                    try await CommentService.shared.unlikeComment(commentId: comment.id, userId: userId)
                    await MainActor.run {
                        comments[index].likeCount -= 1
                    }
                } else {
                    try await CommentService.shared.likeComment(commentId: comment.id, userId: userId)
                    await MainActor.run {
                        comments[index].likeCount += 1
                    }
                }
            } catch {
                print("🔴 [CommentsView] toggleLike error: \(error)")
            }
        }
    }
}

// MARK: - コメントスレッド
struct CommentThreadView: View {
    let comment: Comment
    let allComments: [Comment]
    let postOwnerId: UUID
    let currentUserId: UUID?
    var onReply: (Comment) -> Void
    var onDelete: (Comment) -> Void
    var onLikeToggle: (Comment) -> Void

    var replies: [Comment] {
        allComments.filter { $0.parentCommentId == comment.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommentRowView(
                comment: comment,
                postOwnerId: postOwnerId,
                currentUserId: currentUserId,
                isReply: false,
                onReply: { onReply(comment) },
                onDelete: { onDelete(comment) },
                onLikeToggle: { onLikeToggle(comment) }
            )

            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(replies) { reply in
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 2)
                                .padding(.leading, 20)

                            CommentRowView(
                                comment: reply,
                                postOwnerId: postOwnerId,
                                currentUserId: currentUserId,
                                isReply: true,
                                onReply: { onReply(reply) },
                                onDelete: { onDelete(reply) },
                                onLikeToggle: { onLikeToggle(reply) }
                            )
                            .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - コメント行
struct CommentRowView: View {
    let comment: Comment
    let postOwnerId: UUID
    let currentUserId: UUID?
    let isReply: Bool
    var onReply: () -> Void
    var onDelete: () -> Void
    var onLikeToggle: () -> Void

    @State private var isLiked = false
    @State private var localLikeCount: Int = 0

    var isPostOwner: Bool {
        comment.userId == postOwnerId
    }

    var isMyComment: Bool {
        currentUserId == comment.userId
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let user = comment.user {
                UserAvatarView(user: user, size: isReply ? 32 : 40, showMutualBorder: true, currentUserId: currentUserId)
            } else {
                InitialAvatarView("?", size: isReply ? 32 : 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.user?.displayName ?? "ユーザー")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isPostOwner ? .purple : .primary)

                    if isPostOwner {
                        Text("投稿者")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }

                    Text("@\(comment.user?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(timeAgoString(from: comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(comment.content)
                    .font(.body)

                HStack(spacing: 16) {
                    Button(action: onReply) {
                        Label("返信", systemImage: "arrowshape.turn.up.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // いいねボタン
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLiked.toggle()
                            localLikeCount += isLiked ? 1 : -1
                        }
                        onLikeToggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor(isLiked ? .pink : .secondary)
                            if localLikeCount > 0 {
                                Text("\(localLikeCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPostOwner ? Color.purple.opacity(0.1) : Color.clear)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isMyComment {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
        }
        .onAppear {
            localLikeCount = comment.likeCount
            checkLikeStatus()
        }
    }

    private func checkLikeStatus() {
        guard let userId = currentUserId else { return }
        Task {
            do {
                let liked = try await CommentService.shared.isCommentLiked(commentId: comment.id, userId: userId)
                await MainActor.run {
                    isLiked = liked
                }
            } catch {
                print("🔴 [CommentRow] checkLikeStatus error: \(error)")
            }
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)

        if seconds < 60 {
            return "たった今"
        } else if seconds < 3600 {
            return "\(seconds / 60)分前"
        } else if seconds < 86400 {
            return "\(seconds / 3600)時間前"
        } else if seconds < 604800 {
            return "\(seconds / 86400)日前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}
