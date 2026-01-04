// Views/Main/MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
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
            
            // 5. マイページ
            MyPageView()
                .tabItem {
                    Label("プロフィール", systemImage: "person.fill")
                }
                .tag(4)
        }
        .accentColor(.purple)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthService())
    }
}
