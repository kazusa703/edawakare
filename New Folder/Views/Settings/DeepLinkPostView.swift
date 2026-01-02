// Views/Settings/DeepLinkPostView.swift

import SwiftUI

struct DeepLinkPostView: View {
    let postId: UUID
    @EnvironmentObject var authService: AuthService  // 追加
    @Environment(\.dismiss) private var dismiss
    @State private var post: Post?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("読み込み中...")
                            .foregroundColor(.secondary)
                    }
                } else if let post = post {
                    PostDetailView(post: post)
                        .environmentObject(authService)  // 追加
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("投稿が見つかりませんでした")
                            .font(.headline)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button("閉じる") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle("共有された投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                    }
                }
            }
        }
        .task {
            await loadPost()
        }
    }
    
    private func loadPost() async {
        print("🔗 [DeepLinkPostView] 投稿取得開始: \(postId)")
        
        do {
            post = try await PostService.shared.fetchPost(postId: postId)
            print("✅ [DeepLinkPostView] 投稿取得成功")
        } catch {
            errorMessage = error.localizedDescription
            print("🔴 [DeepLinkPostView] 投稿取得エラー: \(error)")
        }
        
        isLoading = false
    }
}
