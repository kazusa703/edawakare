// ViewModels/FeedViewModel.swift
// フィードビューモデル（Supabase連携版）

import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var followingPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - おすすめ投稿を取得
    func fetchPosts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            posts = try await PostService.shared.fetchPosts()
            isLoading = false
        } catch {
            print("🔴 [FeedViewModel] fetchPosts error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - フォロー中の投稿を取得
    func fetchFollowingPosts(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            followingPosts = try await PostService.shared.fetchFollowingPosts(userId: userId)
            isLoading = false
        } catch {
            print("🔴 [FeedViewModel] fetchFollowingPosts error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - ユーザーの投稿を取得
    func fetchUserPosts(userId: UUID) async -> [Post] {
        do {
            return try await PostService.shared.fetchUserPosts(userId: userId)
        } catch {
            print("🔴 [FeedViewModel] fetchUserPosts error: \(error)")
            return []
        }
    }
    
    // MARK: - 投稿を作成
    func createPost(userId: UUID, centerNodeText: String, nodes: [NodeInput], connections: [ConnectionInput]) async -> Post? {
        isLoading = true
        
        do {
            let post = try await PostService.shared.createPost(
                userId: userId,
                centerNodeText: centerNodeText,
                nodes: nodes,
                connections: connections
            )
            
            posts.insert(post, at: 0)
            isLoading = false
            return post
            
        } catch {
            print("🔴 [FeedViewModel] createPost error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
    
    // MARK: - 投稿を削除
    func deletePost(postId: UUID) async -> Bool {
        do {
            try await PostService.shared.deletePost(postId: postId)
            posts.removeAll { $0.id == postId }
            followingPosts.removeAll { $0.id == postId }
            return true
        } catch {
            print("🔴 [FeedViewModel] deletePost error: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - いいね
    func likePost(userId: UUID, post: Post) async {
        do {
            try await InteractionService.shared.likePost(userId: userId, postId: post.id)
            
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].likeCount += 1
            }
        } catch {
            print("🔴 [FeedViewModel] likePost error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func unlikePost(userId: UUID, post: Post) async {
        do {
            try await InteractionService.shared.unlikePost(userId: userId, postId: post.id)
            
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].likeCount -= 1
            }
        } catch {
            print("🔴 [FeedViewModel] unlikePost error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - ブックマーク
    func bookmarkPost(userId: UUID, postId: UUID) async {
        do {
            try await InteractionService.shared.bookmarkPost(userId: userId, postId: postId)
        } catch {
            print("🔴 [FeedViewModel] bookmarkPost error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func unbookmarkPost(userId: UUID, postId: UUID) async {
        do {
            try await InteractionService.shared.unbookmarkPost(userId: userId, postId: postId)
        } catch {
            print("🔴 [FeedViewModel] unbookmarkPost error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - 検索
    func searchPosts(query: String) async -> [Post] {
        do {
            return try await PostService.shared.searchByNodeText(query: query)
        } catch {
            print("🔴 [FeedViewModel] searchPosts error: \(error)")
            return []
        }
    }
}
