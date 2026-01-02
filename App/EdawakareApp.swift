// App/EdawakareApp.swift

import SwiftUI

@main
struct EdawakareApp: App {
    @StateObject private var authService = AuthService()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var deepLinkPostId: UUID? = nil
    
    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkPostId: $deepLinkPostId)
                .environmentObject(authService)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    // MARK: - ディープリンク処理
    private func handleDeepLink(_ url: URL) {
        print("🔗 [DeepLink] 受信: \(url)")
        print("🔗 [DeepLink] scheme: \(url.scheme ?? "nil")")
        print("🔗 [DeepLink] host: \(url.host ?? "nil")")
        print("🔗 [DeepLink] path: \(url.path)")
        print("🔗 [DeepLink] pathComponents: \(url.pathComponents)")
        
        // edawakare://post/xxxxx の形式をパース
        guard url.scheme == "edawakare" else {
            print("🔴 [DeepLink] 不明なスキーム")
            return
        }
        
        switch url.host {
        case "post":
            // edawakare://post/{postId}
            if let postIdString = url.pathComponents.dropFirst().first,
               let postId = UUID(uuidString: postIdString) {
                print("✅ [DeepLink] 投稿ID: \(postId)")
                deepLinkPostId = postId
            } else {
                print("🔴 [DeepLink] 投稿IDのパースに失敗")
            }
            
        case "user":
            // edawakare://user/{userId} - 将来の拡張用
            print("ℹ️ [DeepLink] ユーザーリンク（未実装）")
            
        default:
            print("🔴 [DeepLink] 不明なホスト: \(url.host ?? "nil")")
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @Binding var deepLinkPostId: UUID?
    
    var body: some View {
        Group {
            if authService.isLoading {
                // 起動時のセッション確認中
                LaunchScreenView()
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .sheet(item: $deepLinkPostId) { postId in
            DeepLinkPostView(postId: postId)
                .environmentObject(authService)  // これを追加
        }
    }
}

// MARK: - 起動画面（セッション確認中に表示）
struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("枝分かれ")
                    .font(.title)
                    .fontWeight(.bold)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - UUID を Identifiable に準拠させる
extension UUID: Identifiable {
    public var id: UUID { self }
}
