// Views/Components/AnimatedButtons.swift

import SwiftUI

// MARK: - アニメーション付きいいねボタン
struct AnimatedLikeButton: View {
    @Binding var isLiked: Bool
    var likeCount: Int
    var onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { scale = 1.3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { scale = 1.0 }
            }
            HapticManager.shared.lightImpact()
            onTap()
        }) {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundColor(isLiked ? .pink : .secondary)
                    .scaleEffect(scale)
                if likeCount > 0 {
                    Text("\(likeCount)")
                        .font(.subheadline)
                        .foregroundColor(isLiked ? .pink : .secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - アニメーション付きブックマークボタン
struct AnimatedBookmarkButton: View {
    @Binding var isBookmarked: Bool
    var onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            withAnimation(.easeInOut(duration: 0.3)) { scale = 1.2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { scale = 1.0 }
            }
            onTap()
        }) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18))
                .foregroundColor(isBookmarked ? .purple : .secondary)
                .scaleEffect(scale)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - アニメーション付きフォローボタン
struct AnimatedFollowButton: View {
    @Binding var isFollowing: Bool
    var onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { scale = 0.85 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { scale = 1.1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { scale = 1.0 }
            }
            onTap()
        }) {
            Text(isFollowing ? "フォロー中" : "フォロー")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isFollowing ? .secondary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isFollowing ? Color(.systemGray5) : Color.purple)
                )
                .scaleEffect(scale)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - コメントボタン
struct CommentButton: View {
    var commentCount: Int
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                if commentCount > 0 {
                    Text("\(commentCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
