// Views/Main/Profile/ProfileViews.swift

import SwiftUI

// MARK: - 他ユーザーのプロフィール画面
struct UserProfileView: View {
    @EnvironmentObject var authService: AuthService
    let userId: UUID
    @State private var user: User?
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var showChat = false
    @State private var conversation: Conversation?
    
    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let user = user {
                ScrollView {
                    VStack(spacing: 0) {
                        ProfileHeaderSection(
                            user: user,
                            isFollowing: isFollowing,
                            onFollowToggle: toggleFollow,
                            onMessageTap: startDM  // 追加
                        )
                        Divider()
                        PostGridSection(posts: posts)
                    }
                }
            } else {
                ErrorView(message: "ユーザーが見つかりません")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: {}) {
                        Label("ブロック", systemImage: "hand.raised")
                    }
                    Button(role: .destructive, action: {}) {
                        Label("通報", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .task {
            await loadUserData()
        }
        .navigationDestination(isPresented: $showChat) {
            if let conversation = conversation {
                ChatView(conversation: conversation)
                    .environmentObject(authService)
            }
        }
    }
    
    private func loadUserData() async {
        isLoading = true
        do {
            self.user = try await UserService.shared.fetchUser(userId: userId)
            self.posts = try await PostService.shared.fetchUserPosts(userId: userId)
            
            if let currentUserId = authService.currentUser?.id {
                self.isFollowing = try await InteractionService.shared.isFollowing(
                    followerId: currentUserId,
                    followingId: userId
                )
            }
        } catch {
            print("🔴 ユーザーデータ読み込みエラー: \(error)")
        }
        isLoading = false
    }
    
    private func toggleFollow() {
        guard let currentUserId = authService.currentUser?.id else { return }
        Task {
            do {
                if isFollowing {
                    try await InteractionService.shared.unfollow(
                        followerId: currentUserId,
                        followingId: userId
                    )
                } else {
                    try await InteractionService.shared.follow(
                        followerId: currentUserId,
                        followingId: userId
                    )
                }
                isFollowing.toggle()
            } catch {
                print("🔴 フォロー操作エラー: \(error)")
            }
        }
    }
    
    // DM開始
    private func startDM() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            do {
                print("🟡 [UserProfile] DM開始 - to: \(userId)")
                let conv = try await MessageService.shared.createConversation(
                    user1Id: currentUserId,
                    user2Id: userId
                )
                
                // otherUserを設定
                var mutableConv = conv
                mutableConv.otherUser = self.user
                
                await MainActor.run {
                    self.conversation = mutableConv
                    self.showChat = true
                }
                print("✅ [UserProfile] DM会話作成成功")
            } catch {
                print("🔴 [UserProfile] DM開始エラー: \(error)")
            }
        }
    }
}

// MARK: - プロフィールヘッダーセクション
struct ProfileHeaderSection: View {
    let user: User
    let isFollowing: Bool
    var onFollowToggle: () -> Void
    var onMessageTap: () -> Void  // 追加
    
    var body: some View {
        VStack(spacing: 16) {
            AvatarView(url: user.avatarUrl, size: 80)
            
            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let bio = user.bio {
                Text(bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // ボタン行
            HStack(spacing: 16) {
                // フォローボタン
                Button(action: onFollowToggle) {
                    Text(isFollowing ? "フォロー中" : "フォローする")
                        .fontWeight(.semibold)
                        .frame(width: 140, height: 40)
                        .background(isFollowing ? Color.clear : Color.purple)
                        .foregroundColor(isFollowing ? .purple : .white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.purple, lineWidth: 2)
                        )
                }
                
                // DMボタン
                Button(action: onMessageTap) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18))
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.purple)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.bottom, 16)
        }
        .padding(.top)
    }
}

// MARK: - 投稿グリッドセクション
struct PostGridSection: View {
    let posts: [Post]
    
    var body: some View {
        if posts.isEmpty {
            VStack(spacing: 20) {
                Spacer().frame(height: 40)
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("投稿がありません")
                    .foregroundColor(.secondary)
            }
        } else {
            LazyVStack(spacing: 16) {
                ForEach(posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostThumbnailCard(post: post)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - 投稿サムネイルカード
struct PostThumbnailCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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
                
                Text("\(post.nodes?.count ?? 0) ノード")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Label("\(post.likeCount)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.right")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - プロフィール編集画面
struct EditProfileView: View {
    @Binding var user: User
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section("プロフィール画像") {
                HStack {
                    Spacer()
                    AvatarView(url: user.avatarUrl, size: 80)
                    Spacer()
                }
                .padding(.vertical, 8)
                
                Button("画像を変更") {
                    // 画像選択（後で実装）
                }
                .frame(maxWidth: .infinity)
            }
            
            Section("プロフィール情報") {
                TextField("表示名", text: $displayName)
                TextField("ユーザーID", text: $username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            Section("自己紹介") {
                TextEditor(text: $bio)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle("プロフィール編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveProfile()
                }
                .disabled(isSaving || displayName.isEmpty || username.isEmpty)
            }
        }
        .onAppear {
            displayName = user.displayName
            username = user.username
            bio = user.bio ?? ""
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            do {
                try await authService.updateProfile(
                    displayName: displayName,
                    username: username,
                    bio: bio.isEmpty ? nil : bio
                )
                
                await MainActor.run {
                    user.displayName = displayName
                    user.username = username
                    user.bio = bio.isEmpty ? nil : bio
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}
