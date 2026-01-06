// App/EdawakareApp.swift

import SwiftUI
import Firebase
import FirebaseMessaging
import UserNotifications
import Supabase

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Firebase初期化
        FirebaseApp.configure()
        
        // Messagingデリゲート設定
        Messaging.messaging().delegate = self
        
        // 通知デリゲート設定
        UNUserNotificationCenter.current().delegate = self
        
        // 通知許可リクエスト
        requestNotificationPermission(application)
        
        return true
    }
    
    // MARK: - 通知許可リクエスト
    private func requestNotificationPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("🔔 [Push] 通知許可: \(granted)")
            if let error = error {
                print("🔴 [Push] 許可エラー: \(error)")
            }
            
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }
    
    // MARK: - APNsトークン受信
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("✅ [Push] APNsトークン登録完了")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔴 [Push] APNsトークン登録失敗: \(error)")
    }
    
    // MARK: - FCMトークン受信
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("✅ [Push] FCMトークン: \(token)")
        
        // Supabaseに保存
        Task {
            await saveFCMToken(token)
        }
    }
    
    // MARK: - FCMトークンをSupabaseに保存
    private func saveFCMToken(_ token: String) async {
        guard let userId = SupabaseClient.shared.client.auth.currentUser?.id else {
            print("🔴 [Push] ユーザー未ログイン、トークン保存スキップ")
            return
        }
        
        do {
            try await PushNotificationService.shared.saveDeviceToken(userId: userId, fcmToken: token)
            print("✅ [Push] FCMトークン保存完了")
        } catch {
            print("🔴 [Push] FCMトークン保存失敗: \(error)")
        }
    }
    
    // MARK: - フォアグラウンドで通知受信
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("🔔 [Push] フォアグラウンド通知受信: \(userInfo)")
        
        // バナーとサウンドを表示
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - 通知タップ時
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("🔔 [Push] 通知タップ: \(userInfo)")
        
        // 通知タイプに応じた画面遷移（後で実装）
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // 通知タイプごとの画面遷移処理
        if let type = userInfo["type"] as? String {
            switch type {
            case "like", "comment":
                if let postIdString = userInfo["post_id"] as? String,
                   let postId = UUID(uuidString: postIdString) {
                    NotificationCenter.default.post(
                        name: .openPostFromPush,
                        object: nil,
                        userInfo: ["postId": postId]
                    )
                }
            case "follow":
                if let userIdString = userInfo["user_id"] as? String,
                   let userId = UUID(uuidString: userIdString) {
                    NotificationCenter.default.post(
                        name: .openUserFromPush,
                        object: nil,
                        userInfo: ["userId": userId]
                    )
                }
            case "dm":
                if let conversationIdString = userInfo["conversation_id"] as? String,
                   let conversationId = UUID(uuidString: conversationIdString) {
                    NotificationCenter.default.post(
                        name: .openDMFromPush,
                        object: nil,
                        userInfo: ["conversationId": conversationId]
                    )
                }
            default:
                break
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openPostFromPush = Notification.Name("openPostFromPush")
    static let openUserFromPush = Notification.Name("openUserFromPush")
    static let openDMFromPush = Notification.Name("openDMFromPush")
}

// MARK: - Main App
@main
struct EdawakareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
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
                .onAppear {
                    // ログイン後にFCMトークンを再保存
                    updateFCMTokenIfNeeded()
                }
                .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                    if isAuthenticated {
                        updateFCMTokenIfNeeded()
                    }
                }
        }
    }
    
    // MARK: - FCMトークン更新
    private func updateFCMTokenIfNeeded() {
        guard authService.isAuthenticated,
              let userId = authService.currentUser?.id else { return }
        
        Messaging.messaging().token { token, error in
            if let token = token {
                Task {
                    try? await PushNotificationService.shared.saveDeviceToken(userId: userId, fcmToken: token)
                }
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
        
        guard url.scheme == "edawakare" else {
            print("🔴 [DeepLink] 不明なスキーム")
            return
        }
        
        switch url.host {
        case "post":
            if let postIdString = url.pathComponents.dropFirst().first,
               let postId = UUID(uuidString: postIdString) {
                print("✅ [DeepLink] 投稿ID: \(postId)")
                deepLinkPostId = postId
            } else {
                print("🔴 [DeepLink] 投稿IDのパースに失敗")
            }
            
        case "user":
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
                LaunchScreenView()
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .sheet(item: $deepLinkPostId) { postId in
            DeepLinkPostView(postId: postId)
                .environmentObject(authService)
        }
    }
}

// MARK: - 起動画面
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

// MARK: - UUID を Identifiable に準拠
extension UUID: Identifiable {
    public var id: UUID { self }
}
