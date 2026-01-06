// Views/Components/ProfileAvatarView.swift

import SwiftUI

// MARK: - プロフィールアバター（URL対応）
struct ProfileAvatarView: View {
    let user: User?
    let size: CGFloat
    
    init(user: User?, size: CGFloat = 40) {
        self.user = user
        self.size = size
    }
    
    var body: some View {
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
