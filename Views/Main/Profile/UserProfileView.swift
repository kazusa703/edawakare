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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if let profile = profile {
                    // プロフィールヘッダー
                    VStack(spacing: 16) {
                        // アイコン
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
                        
                        // フォローボタン（自分以外の場合）
                        if !isCurrentUser {
                            Button(action: toggleFollow) {
                                Text(isFollowing ? "フォロー中" : "フォローする")
                                    .fontWeight(.semibold)
                                    .frame(width: 150)
                                    .padding(.vertical, 10)
                                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.purple)
                                    .foregroundColor(isFollowing ? .primary : .white)
                                    .cornerRadius(20)
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
                            ForEach(posts) { post in
                                NavigationLink(destination: PostDetailView(post: post)) {
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
        .task {
            await loadUserData()
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case iconUrl = "icon_url"
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
