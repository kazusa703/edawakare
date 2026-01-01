// Views/Settings/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            List {
                // プロフィールセクション
                profileSection
                
                // アカウント設定
                accountSection
                
                // サポート
                supportSection
                
                // ログアウト
                logoutSection
                
                // アカウント削除
                deleteAccountSection
                
                // アプリ情報
                appInfoSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("ログアウト", isPresented: $showLogoutAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("ログアウト", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("ログアウトしますか？")
            }
            .alert("アカウントを削除", isPresented: $showDeleteAccountAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    performDeleteAccount()
                }
            } message: {
                Text("この操作は取り消せません。すべてのデータが削除されます。")
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - プロフィールセクション
    private var profileSection: some View {
        Section {
            Button(action: { showEditProfile = true }) {
                HStack(spacing: 12) {
                    ProfileAvatarView(user: authService.currentUser)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authService.currentUser?.displayName ?? "ユーザー")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("@\(authService.currentUser?.username ?? "unknown")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - アカウント設定セクション
    private var accountSection: some View {
        Section("アカウント") {
            NavigationLink(destination: PrivacySettingsView()) {
                Label("プライバシー設定", systemImage: "lock")
            }
            NavigationLink(destination: NotificationSettingsView()) {
                Label("通知設定", systemImage: "bell")
            }
            NavigationLink(destination: BlockedUsersView()) {
                Label("ブロック中のユーザー", systemImage: "person.crop.circle.badge.minus")
            }
        }
    }
    
    // MARK: - サポートセクション
    private var supportSection: some View {
        Section("サポート") {
            NavigationLink(destination: HelpView()) {
                Label("ヘルプ", systemImage: "questionmark.circle")
            }
            NavigationLink(destination: TermsView()) {
                Label("利用規約", systemImage: "doc.text")
            }
            NavigationLink(destination: PrivacyPolicyView()) {
                Label("プライバシーポリシー", systemImage: "hand.raised")
            }
        }
    }
    
    // MARK: - ログアウトセクション
    private var logoutSection: some View {
        Section {
            Button(action: { showLogoutAlert = true }) {
                Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - アカウント削除セクション
    private var deleteAccountSection: some View {
        Section {
            Button(action: { showDeleteAccountAlert = true }) {
                Label("アカウントを削除", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - アプリ情報セクション
    private var appInfoSection: some View {
        Section {
            HStack {
                Text("バージョン")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - アクション
    private func performLogout() {
        Task {
            try? await authService.signOut()
            dismiss()
        }
    }
    
    private func performDeleteAccount() {
        Task {
            try? await authService.deleteAccount()
            dismiss()
        }
    }
}

// MARK: - プロフィールアバター
struct ProfileAvatarView: View {
    let user: User?
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(user?.displayName.prefix(1) ?? "?"))
                    .font(.headline)
                    .foregroundColor(.white)
            )
    }
}

// MARK: - プロフィール編集シート
struct EditProfileSheet: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("プロフィール画像") {
                    HStack {
                        Spacer()
                        ProfileAvatarView(user: authService.currentUser)
                            .scaleEffect(1.6)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                
                Section("プロフィール情報") {
                    TextField("表示名", text: $displayName)
                    TextField("ユーザーID", text: $username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section("自己紹介") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProfile()
                    }
                    .disabled(isSaving || displayName.isEmpty || username.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                displayName = authService.currentUser?.displayName ?? ""
                username = authService.currentUser?.username ?? ""
                bio = authService.currentUser?.bio ?? ""
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            do {
                try await authService.updateProfile(
                    displayName: displayName,
                    username: username,
                    bio: bio.isEmpty ? nil : bio
                )
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - プレースホルダービュー
struct PrivacySettingsView: View {
    var body: some View {
        List {
            Toggle("非公開アカウント", isOn: .constant(false))
            Picker("DM受信設定", selection: .constant(0)) {
                Text("全員").tag(0)
                Text("フォロワーのみ").tag(1)
                Text("受け取らない").tag(2)
            }
        }
        .navigationTitle("プライバシー設定")
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        List {
            Toggle("いいね通知", isOn: .constant(true))
            Toggle("コメント通知", isOn: .constant(true))
            Toggle("フォロー通知", isOn: .constant(true))
            Toggle("DM通知", isOn: .constant(true))
        }
        .navigationTitle("通知設定")
    }
}

struct BlockedUsersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.minus")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("ブロック中のユーザーはいません")
                .foregroundColor(.secondary)
        }
        .navigationTitle("ブロック中のユーザー")
    }
}

struct HelpView: View {
    var body: some View {
        List {
            NavigationLink("よくある質問") { Text("FAQ") }
            NavigationLink("お問い合わせ") { Text("Contact") }
        }
        .navigationTitle("ヘルプ")
    }
}

struct TermsView: View {
    var body: some View {
        ScrollView {
            Text("利用規約の内容がここに表示されます。")
                .padding()
        }
        .navigationTitle("利用規約")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("プライバシーポリシーの内容がここに表示されます。")
                .padding()
        }
        .navigationTitle("プライバシーポリシー")
    }
}
