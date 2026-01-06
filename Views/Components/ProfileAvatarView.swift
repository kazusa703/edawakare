// Views/Components/ProfileAvatarView.swift

import SwiftUI

// MARK: - ユーザーアバター（相互フォロー縁色対応）
struct UserAvatarView: View {
    let user: User
    let size: CGFloat
    let showMutualBorder: Bool
    let currentUserId: UUID?

    @State private var isMutualFollow = false

    init(user: User, size: CGFloat = 40, showMutualBorder: Bool = true, currentUserId: UUID? = nil) {
        self.user = user
        self.size = size
        self.showMutualBorder = showMutualBorder
        self.currentUserId = currentUserId
    }

    var body: some View {
        ZStack {
            // 相互フォロー時の縁色
            if showMutualBorder && isMutualFollow, let colorHex = user.iconBorderColor {
                Circle()
                    .stroke(Color(hex: colorHex) ?? .purple, lineWidth: 3)
                    .frame(width: size + 6, height: size + 6)
            }

            Group {
                if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
        .task {
            if showMutualBorder {
                await checkMutualFollow()
            }
        }
    }

    private var placeholderView: some View {
        Circle()
            .fill(AppColors.primaryGradient)
            .overlay(
                Text(String(user.displayName.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func checkMutualFollow() async {
        guard let currentUserId = currentUserId, currentUserId != user.id else { return }

        do {
            let mutual = try await InteractionService.shared.isMutualFollow(userId1: currentUserId, userId2: user.id)
            await MainActor.run {
                isMutualFollow = mutual
            }
        } catch {
            print("🔴 [UserAvatarView] エラー: \(error)")
        }
    }
}

// MARK: - プロフィールアバター（URL対応・後方互換用）
struct ProfileAvatarView: View {
    let user: User?
    let size: CGFloat
    var borderColor: Color? = nil

    init(user: User?, size: CGFloat = 40, borderColor: Color? = nil) {
        self.user = user
        self.size = size
        self.borderColor = borderColor
    }

    var body: some View {
        ZStack {
            // 縁色（相互フォロー時）
            if let borderColor = borderColor {
                Circle()
                    .stroke(borderColor, lineWidth: 3)
                    .frame(width: size + 6, height: size + 6)
            }

            Group {
                if let avatarUrl = user?.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }

    private var placeholderView: some View {
        Circle()
            .fill(AppColors.primaryGradient)
            .overlay(
                Text(String(user?.displayName.prefix(1) ?? "?"))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - 相互フォロー対応アバター（後方互換用）
struct MutualFollowAvatarView: View {
    let user: User
    let currentUserId: UUID?
    let size: CGFloat

    init(user: User, currentUserId: UUID?, size: CGFloat = 40) {
        self.user = user
        self.currentUserId = currentUserId
        self.size = size
    }

    var body: some View {
        UserAvatarView(user: user, size: size, showMutualBorder: true, currentUserId: currentUserId)
    }
}

// MARK: - シンプルアバター（イニシャルのみ）
struct InitialAvatarView: View {
    let name: String
    let size: CGFloat
    
    init(_ name: String, size: CGFloat = 40) {
        self.name = name
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(AppColors.primaryGradient)
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}
