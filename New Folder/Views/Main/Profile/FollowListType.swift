// Views/Follow/FollowListView.swift

import SwiftUI

enum FollowListType {
    case followers
    case following
    
    var title: String {
        switch self {
        case .followers: return "フォロワー"
        case .following: return "フォロー中"
        }
    }
}

struct FollowListView: View {
    let userId: UUID
    let listType: FollowListType
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var users: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if users.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: listType == .followers ? "person.2" : "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(listType == .followers ? "まだフォロワーがいません" : "まだ誰もフォローしていません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(users) { user in
                        FollowUserRow(user: user, currentUserId: authService.currentUser?.id)
                            .environmentObject(authService)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(listType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    private func loadUsers() async {
        do {
            switch listType {
            case .followers:
                users = try await InteractionService.shared.fetchFollowers(userId: userId)
            case .following:
                users = try await InteractionService.shared.fetchFollowing(userId: userId)
            }
        } catch {
            print("🔴 [FollowListView] 取得エラー: \(error)")
        }
        isLoading = false
    }
}

// MARK: - フォローユーザー行
struct FollowUserRow: View {
    let user: User
    let currentUserId: UUID?
    
    @EnvironmentObject var authService: AuthService
    @State private var isFollowing = false
    @State private var isLoading = false
    
    // 自分自身かどうか
    var isMe: Bool {
        user.id == currentUserId
    }
    
    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: UserProfileView(userId: user.id).environmentObject(authService)) {
                HStack(spacing: 12) {
                    ProfileAvatarView(user: user, size: 50)
                    
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
            }
            
            Spacer()
            
            // 自分以外にはフォローボタンを表示
            if !isMe {
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
        }
        .padding(.vertical, 4)
        .task {
            await checkFollowStatus()
        }
    }
    
    private func checkFollowStatus() async {
        guard let currentUserId = currentUserId, !isMe else { return }
        
        do {
            isFollowing = try await InteractionService.shared.isFollowing(
                followerId: currentUserId,
                followingId: user.id
            )
        } catch {
            print("🔴 [FollowUserRow] フォロー状態確認エラー: \(error)")
        }
    }
    
    private func toggleFollow() {
        guard let currentUserId = currentUserId else { return }
        
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
                print("🔴 [FollowUserRow] フォロー操作エラー: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
