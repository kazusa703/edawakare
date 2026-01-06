// Views/Main/MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    @State private var dmUnreadCount = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. ホーム（フィード）
            HomeFeedView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(0)

            // 2. 検索
            SearchView()
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }
                .tag(1)

            // 3. 通知
            NotificationsView()
                .tabItem {
                    Label("通知", systemImage: "bell.fill")
                }
                .tag(2)

            // 4. メッセージ（DMListView を使用）
            DMListView()
                .tabItem {
                    Label("メッセージ", systemImage: "envelope.fill")
                }
                .tag(3)
                .badge(dmUnreadCount > 0 ? dmUnreadCount : 0)

            // 5. マイページ
            MyPageView()
                .tabItem {
                    Label("プロフィール", systemImage: "person.fill")
                }
                .tag(4)
        }
        .accentColor(.purple)
        .task {
            await fetchDMUnreadCount()
        }
        .onChange(of: selectedTab) { _, newValue in
            // DMタブを開いたら未読数をリセット
            if newValue == 3 {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待つ
                    await fetchDMUnreadCount()
                }
            }
        }
    }

    private func fetchDMUnreadCount() async {
        guard let userId = authService.currentUser?.id else { return }
        do {
            let count = try await MessageService.shared.fetchUnreadCount(userId: userId)
            await MainActor.run {
                dmUnreadCount = count
            }
        } catch {
            print("🔴 [MainTabView] DM未読数取得エラー: \(error)")
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthService())
    }
}
