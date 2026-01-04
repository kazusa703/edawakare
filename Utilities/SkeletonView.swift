// Utilities/SkeletonView.swift

import SwiftUI

// MARK: - スケルトン基本パーツ
struct SkeletonBox: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.3))
            .frame(width: width, height: height)
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40
    
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
    }
}

// MARK: - ホームフィード用スケルトン
struct PostCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ユーザー情報
            HStack(spacing: 10) {
                SkeletonCircle(size: 40)
                
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBox(width: 100, height: 14)
                    SkeletonBox(width: 60, height: 12)
                }
                
                Spacer()
                
                SkeletonBox(width: 40, height: 12)
            }
            
            // 中央ノード
            HStack(spacing: 8) {
                SkeletonCircle(size: 12)
                SkeletonBox(width: 150, height: 18)
            }
            
            // 子ノード
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    SkeletonBox(width: 20, height: 2)
                    SkeletonCircle(size: 8)
                    SkeletonBox(width: 120, height: 14)
                }
                HStack(spacing: 8) {
                    SkeletonBox(width: 20, height: 2)
                    SkeletonCircle(size: 8)
                    SkeletonBox(width: 100, height: 14)
                }
            }
            .padding(.leading, 16)
            
            // アクションボタン
            HStack(spacing: 24) {
                SkeletonBox(width: 40, height: 14)
                SkeletonBox(width: 40, height: 14)
                Spacer()
                SkeletonBox(width: 24, height: 14)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - ホームフィードスケルトン一覧
struct HomeFeedSkeleton: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { _ in
                    PostCardSkeleton()
                }
            }
            .padding()
        }
    }
}

// MARK: - プロフィール用スケルトン
struct ProfileSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            // ヘッダー
            VStack(spacing: 12) {
                SkeletonCircle(size: 80)
                SkeletonBox(width: 120, height: 20)
                SkeletonBox(width: 80, height: 14)
            }
            .padding(.top, 20)
            
            // フォロー情報
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    SkeletonBox(width: 30, height: 18)
                    SkeletonBox(width: 50, height: 12)
                }
                VStack(spacing: 4) {
                    SkeletonBox(width: 30, height: 18)
                    SkeletonBox(width: 60, height: 12)
                }
                VStack(spacing: 4) {
                    SkeletonBox(width: 30, height: 18)
                    SkeletonBox(width: 60, height: 12)
                }
            }
            
            // 投稿一覧
            LazyVStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    PostCardSkeleton()
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 検索結果用スケルトン
struct SearchResultSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // ユーザー検索結果
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonCircle(size: 44)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBox(width: 100, height: 16)
                        SkeletonBox(width: 70, height: 12)
                    }
                    
                    Spacer()
                    
                    SkeletonBox(width: 70, height: 30, cornerRadius: 15)
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // 投稿検索結果
            ForEach(0..<2, id: \.self) { _ in
                PostCardSkeleton()
                    .padding(.horizontal)
            }
        }
    }
}
