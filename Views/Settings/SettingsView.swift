// Views/Settings/SettingsView.swift

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showEditProfile = false
    @State private var showSwitchAccountAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                profileSection
                accountSection
                bookmarkSection
                supportSection
                logoutSection
                switchAccountSection  // 追加
                deleteAccountSection
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
            .alert("アカウントを切り替え", isPresented: $showSwitchAccountAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("切り替え", role: .destructive) {
                    performSwitchAccount()
                }
            } message: {
                Text("現在のアカウントからログアウトして、別のアカウントでログインします。")
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
                    ProfileAvatarView(user: authService.currentUser, size: 50)
                    
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
            // アカウント情報（追加）
            NavigationLink(destination: AccountInfoView().environmentObject(authService)) {
                Label("アカウント情報", systemImage: "person.text.rectangle")
            }

            NavigationLink(destination: PrivacySettingsView().environmentObject(authService)) {
                Label("プライバシー設定", systemImage: "lock")
            }
            NavigationLink(destination: IconBorderColorSettingsView().environmentObject(authService)) {
                Label("アイコン縁色", systemImage: "circle.circle")
            }
            NavigationLink(destination: FavoriteStyleEditorView()) {
                Label("プリセット編集", systemImage: "paintpalette")
            }
            NavigationLink(destination: NotificationSettingsView().environmentObject(authService)) {
                Label("通知設定", systemImage: "bell")
            }
            NavigationLink(destination: BlockedUsersView().environmentObject(authService)) {
                Label("ブロック中のユーザー", systemImage: "person.crop.circle.badge.minus")
            }
        }
    }
    
    // MARK: - ブックマークセクション
    private var bookmarkSection: some View {
        Section {
            NavigationLink(destination: BookmarksListView().environmentObject(authService)) {
                Label("ブックマーク", systemImage: "bookmark.fill")
                    .foregroundColor(.purple)
            }
            
            NavigationLink(destination: LikedPostsListView().environmentObject(authService)) {
                Label("いいね", systemImage: "heart.fill")
                    .foregroundColor(.pink)
            }
            
            // 下書きを追加
            NavigationLink(destination: DraftsListView().environmentObject(authService)) {
                HStack {
                    Label("下書き", systemImage: "doc.text")
                        .foregroundColor(.orange)
                    Spacer()
                    if DraftManager.shared.drafts.count > 0 {
                        Text("\(DraftManager.shared.drafts.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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
    
    // MARK: - アカウント切り替えセクション（追加）
    private var switchAccountSection: some View {
        Section {
            Button(action: { showSwitchAccountAlert = true }) {
                Label("アカウントを切り替え", systemImage: "arrow.left.arrow.right")
                    .foregroundColor(.blue)
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
    
    private func performSwitchAccount() {
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

// MARK: - アカウント情報画面（新規追加）
struct AccountInfoView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        List {
            Section("ログイン情報") {
                HStack {
                    Label("メールアドレス", systemImage: "envelope")
                    Spacer()
                    Text(authService.currentUser?.email ?? "不明")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            
            Section("アカウント作成日") {
                HStack {
                    Label("開始日", systemImage: "calendar")
                    Spacer()
                    if let date = authService.currentUser?.createdAt {
                        Text(formatDate(date))
                            .foregroundColor(.secondary)
                    } else {
                        Text("不明")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let date = authService.currentUser?.createdAt {
                    HStack {
                        Label("利用期間", systemImage: "clock")
                        Spacer()
                        Text(daysUsing(since: date))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("ユーザー情報") {
                HStack {
                    Label("ユーザーID", systemImage: "number")
                    Spacer()
                    Text(authService.currentUser?.id.uuidString.prefix(8).uppercased() ?? "不明")
                        .foregroundColor(.secondary)
                        .font(.system(.subheadline, design: .monospaced))
                }
                
                HStack {
                    Label("ユーザー名", systemImage: "at")
                    Spacer()
                    Text("@\(authService.currentUser?.username ?? "unknown")")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("アカウント情報")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func daysUsing(since date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        
        if days == 0 {
            return "今日から"
        } else if days == 1 {
            return "1日"
        } else if days < 30 {
            return "\(days)日"
        } else if days < 365 {
            let months = days / 30
            return "約\(months)ヶ月"
        } else {
            let years = days / 365
            let remainingMonths = (days % 365) / 30
            if remainingMonths > 0 {
                return "約\(years)年\(remainingMonths)ヶ月"
            } else {
                return "約\(years)年"
            }
        }
    }
}


// MARK: - プロフィール編集シート（アバターアップロード対応）
struct EditProfileSheet: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var isUploadingAvatar = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var previewImage: UIImage?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("プロフィール画像") {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            if let previewImage = previewImage {
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                ProfileAvatarView(user: authService.currentUser, size: 100)
                            }
                            
                            if isUploadingAvatar {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 100, height: 100)
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            
                            if !isUploadingAvatar {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            )
                                            .shadow(radius: 2)
                                    }
                                }
                                .frame(width: 100, height: 100)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .overlay(
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Color.clear
                        }
                        .disabled(isUploadingAvatar)
                    )
                    
                    if authService.currentUser?.avatarUrl != nil || previewImage != nil {
                        Button(role: .destructive) {
                            removeAvatar()
                        } label: {
                            HStack {
                                Spacer()
                                Text("プロフィール画像を削除")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        .disabled(isUploadingAvatar)
                    }
                }
                
                Section("プロフィール情報") {
                    HStack {
                        Text("表示名")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("表示名", text: $displayName)
                    }
                    
                    HStack {
                        Text("ユーザーID")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("ユーザーID", text: $username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                
                Section("自己紹介") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                }
                
                Section {
                    HStack {
                        Text("自己紹介: \(bio.count)/200文字")
                            .font(.caption)
                            .foregroundColor(bio.count > 200 ? .red : .secondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isSaving || isUploadingAvatar)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProfile()
                    }
                    .disabled(isSaving || isUploadingAvatar || displayName.isEmpty || username.isEmpty || bio.count > 200)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                handlePhotoSelection(newItem)
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadCurrentProfile() {
        displayName = authService.currentUser?.displayName ?? ""
        username = authService.currentUser?.username ?? ""
        bio = authService.currentUser?.bio ?? ""
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedImageData = data
                        previewImage = UIImage(data: data)
                    }
                    await uploadAvatar(data: data)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "画像の読み込みに失敗しました"
                    showError = true
                }
            }
        }
    }
    
    private func uploadAvatar(data: Data) async {
        guard let userId = authService.currentUser?.id else { return }
        
        await MainActor.run {
            isUploadingAvatar = true
        }
        
        do {
            let compressedData = compressImage(data: data, maxSize: 500 * 1024)
            let avatarUrl = try await UserService.shared.uploadAvatar(userId: userId, imageData: compressedData)
            
            await MainActor.run {
                authService.currentUser?.avatarUrl = avatarUrl
                isUploadingAvatar = false
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                errorMessage = "画像のアップロードに失敗しました: \(error.localizedDescription)"
                showError = true
                isUploadingAvatar = false
                previewImage = nil
                selectedImageData = nil
            }
        }
    }
    
    private func compressImage(data: Data, maxSize: Int) -> Data {
        guard let image = UIImage(data: data) else { return data }
        
        var compression: CGFloat = 1.0
        var compressedData = image.jpegData(compressionQuality: compression) ?? data
        
        while compressedData.count > maxSize && compression > 0.1 {
            compression -= 0.1
            compressedData = image.jpegData(compressionQuality: compression) ?? data
        }
        
        if compressedData.count > maxSize {
            let scale = sqrt(CGFloat(maxSize) / CGFloat(compressedData.count))
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            compressedData = resizedImage?.jpegData(compressionQuality: 0.8) ?? compressedData
        }
        
        print("📦 [EditProfile] 画像圧縮: \(data.count) → \(compressedData.count) bytes")
        return compressedData
    }
    
    private func removeAvatar() {
        previewImage = nil
        selectedImageData = nil
        
        Task {
            guard let userId = authService.currentUser?.id else { return }
            
            do {
                try await UserService.shared.updateProfile(
                    userId: userId,
                    displayName: displayName,
                    username: username,
                    bio: bio.isEmpty ? nil : bio
                )
                
                await MainActor.run {
                    authService.currentUser?.avatarUrl = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "画像の削除に失敗しました"
                    showError = true
                }
            }
        }
    }
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            guard let userId = authService.currentUser?.id else {
                await MainActor.run {
                    errorMessage = "ユーザー情報が見つかりません"
                    showError = true
                    isSaving = false
                }
                return
            }
            
            do {
                try await UserService.shared.updateProfile(
                    userId: userId,
                    displayName: displayName,
                    username: username,
                    bio: bio.isEmpty ? nil : bio
                )
                
                await MainActor.run {
                    authService.currentUser?.displayName = displayName
                    authService.currentUser?.username = username
                    authService.currentUser?.bio = bio.isEmpty ? nil : bio
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

// MARK: - ブックマーク一覧画面
struct BookmarksListView: View {
    @EnvironmentObject var authService: AuthService
    @State private var bookmarkedPosts: [Post] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if bookmarkedPosts.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("ブックマークした投稿はありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("気になる投稿をブックマークすると\nここに表示されます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(bookmarkedPosts) { post in
                            NavigationLink(destination: PostDetailView(post: post).environmentObject(authService)) {
                                BookmarkPostCard(post: post)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("ブックマーク")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBookmarks()
        }
        .refreshable {
            await loadBookmarks()
        }
    }
    
    private func loadBookmarks() async {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            bookmarkedPosts = try await InteractionService.shared.fetchBookmarks(userId: userId)
        } catch {
            print("🔴 [BookmarksListView] エラー: \(error)")
        }
        isLoading = false
    }
}

// MARK: - いいねした投稿一覧画面
struct LikedPostsListView: View {
    @EnvironmentObject var authService: AuthService
    @State private var likedPosts: [Post] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if likedPosts.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("いいねした投稿はありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("気になる投稿にいいねすると\nここに表示されます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(likedPosts) { post in
                            NavigationLink(destination: PostDetailView(post: post).environmentObject(authService)) {
                                LikedPostCard(post: post)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("いいね")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadLikedPosts()
        }
        .refreshable {
            await loadLikedPosts()
        }
    }
    
    private func loadLikedPosts() async {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            likedPosts = try await InteractionService.shared.fetchLikedPosts(userId: userId)
        } catch {
            print("🔴 [LikedPostsListView] エラー: \(error)")
        }
        isLoading = false
    }
}

// MARK: - いいね投稿カード
struct LikedPostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProfileAvatarView(user: post.user, size: 36)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(post.user?.displayName ?? "ユーザー")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("@\(post.user?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 10, height: 10)
                
                Text(post.centerNodeText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                    Text("\(post.likeCount)")
                        .font(.caption)
                }
                .foregroundColor(.pink)
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.caption)
                    Text("\(post.commentCount)")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                    Text("\(post.nodes?.count ?? 0)")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - ブックマーク投稿カード
struct BookmarkPostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProfileAvatarView(user: post.user, size: 36)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(post.user?.displayName ?? "ユーザー")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("@\(post.user?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.purple)
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 10, height: 10)
                
                Text(post.centerNodeText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.caption)
                    Text("\(post.likeCount)")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.caption)
                    Text("\(post.commentCount)")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                    Text("\(post.nodes?.count ?? 0)")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - プライバシー設定
struct PrivacySettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isPrivate = false
    @State private var dmPermission = 0
    
    var body: some View {
        List {
            Toggle("非公開アカウント", isOn: $isPrivate)
            
            Picker("DM受信設定", selection: $dmPermission) {
                Text("全員").tag(0)
                Text("フォロワーのみ").tag(1)
                Text("受け取らない").tag(2)
            }
        }
        .navigationTitle("プライバシー設定")
        .onAppear {
            isPrivate = authService.currentUser?.isPrivate ?? false
            switch authService.currentUser?.dmPermission {
            case "followers": dmPermission = 1
            case "none": dmPermission = 2
            default: dmPermission = 0
            }
        }
    }
}

// MARK: - 下書き一覧画面
struct DraftsListView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var draftManager = DraftManager.shared
    @State private var selectedDraft: DraftPost?
    @State private var showEditDraft = false
    @State private var showDeleteAlert = false
    @State private var draftToDelete: DraftPost?
    
    var body: some View {
        Group {
            if draftManager.drafts.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("下書きはありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("投稿作成時に「下書き保存」すると\nここに表示されます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List {
                    ForEach(draftManager.drafts) { draft in
                        Button(action: {
                            print("🟡 [Settings] 下書きタップ開始")
                            print("🟡 [Settings] draft.id: \(draft.id)")
                            print("🟡 [Settings] draft.centerNodeText: \(draft.centerNodeText)")
                            print("🟡 [Settings] draft.nodes.count: \(draft.nodes.count)")
                            print("🟡 [Settings] draft.connections.count: \(draft.connections.count)")
                            
                            // 各ノードの詳細
                            for (index, node) in draft.nodes.enumerated() {
                                print("📦 [Settings] DraftNode[\(index)]: id=\(node.id), text=\(node.text), isCenter=\(node.isCenter)")
                            }
                            
                            selectedDraft = draft
                            showEditDraft = true
                            print("✅ [Settings] showEditDraft = true 設定完了")
                        }) {
                            DraftRowView(draft: draft)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                draftToDelete = draft
                                showDeleteAlert = true
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("下書き")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("残り\(draftManager.remainingDraftSlots)枠")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        // 変更後
        .fullScreenCover(item: $selectedDraft) { draft in
            EditDraftView(draft: draft)
        }
        .alert("下書きを削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let draft = draftToDelete {
                    draftManager.deleteDraft(id: draft.id)
                }
            }
        } message: {
            Text("この下書きを削除しますか？")
        }
    }
}

// MARK: - 下書き行
struct DraftRowView: View {
    let draft: DraftPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 10, height: 10)
                
                Text(draft.centerNodeText.isEmpty ? "無題の下書き" : draft.centerNodeText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                    Text("\(draft.nodes.count)")
                        .font(.caption)
                }
                
                Text(formatDate(draft.updatedAt))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 通知設定
struct NotificationSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var settings: NotificationSettings?
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let settings = settings {
                List {
                    // いいねセクション
                    Section("いいね") {
                        Toggle("アプリ内通知", isOn: binding(for: \.likeInAppEnabled))
                        Toggle("プッシュ通知", isOn: binding(for: \.likePushEnabled))
                        batchCountPicker(title: "まとめ通知", keyPath: \.likeBatchCount)
                    }

                    // コメントセクション
                    Section("コメント") {
                        Toggle("アプリ内通知", isOn: binding(for: \.commentInAppEnabled))
                        Toggle("プッシュ通知", isOn: binding(for: \.commentPushEnabled))
                        batchCountPicker(title: "まとめ通知", keyPath: \.commentBatchCount)
                    }

                    // フォローセクション
                    Section("フォロー") {
                        Toggle("アプリ内通知", isOn: binding(for: \.followInAppEnabled))
                        Toggle("プッシュ通知", isOn: binding(for: \.followPushEnabled))
                        batchCountPicker(title: "まとめ通知", keyPath: \.followBatchCount)
                    }

                    // DMセクション
                    Section("DM") {
                        Toggle("アプリ内通知", isOn: binding(for: \.dmInAppEnabled))
                        Toggle("プッシュ通知", isOn: binding(for: \.dmPushEnabled))
                        batchCountPicker(title: "まとめ通知", keyPath: \.dmBatchCount)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("設定を読み込めませんでした")
                        .foregroundColor(.secondary)
                    Button("再読み込み") {
                        Task { await loadSettings() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("通知設定")
        .task {
            await loadSettings()
        }
    }

    // MARK: - Binding Helper
    private func binding(for keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings?[keyPath: keyPath] ?? false },
            set: { newValue in
                settings?[keyPath: keyPath] = newValue
                saveSettings()
            }
        )
    }

    // MARK: - Batch Count Picker
    @ViewBuilder
    private func batchCountPicker(title: String, keyPath: WritableKeyPath<NotificationSettings, Int>) -> some View {
        Picker(title, selection: Binding(
            get: { settings?[keyPath: keyPath] ?? 1 },
            set: { newValue in
                settings?[keyPath: keyPath] = newValue
                saveSettings()
            }
        )) {
            Text("1件ごと").tag(1)
            Text("10件ごと").tag(10)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Load Settings
    private func loadSettings() async {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            if let existingSettings = try await PushNotificationService.shared.getNotificationSettings(userId: userId) {
                settings = existingSettings
            } else {
                settings = NotificationSettings.defaultSettings(userId: userId)
            }
        } catch {
            print("🔴 [NotificationSettings] 読み込みエラー: \(error)")
            settings = NotificationSettings.defaultSettings(userId: userId)
        }
        isLoading = false
    }

    // MARK: - Save Settings
    private func saveSettings() {
        guard let settings = settings else { return }

        Task {
            do {
                try await PushNotificationService.shared.saveNotificationSettings(settings: settings)
                print("✅ [NotificationSettings] 保存完了")
            } catch {
                print("🔴 [NotificationSettings] 保存エラー: \(error)")
            }
        }
    }
}

// MARK: - ブロック中のユーザー
struct BlockedUsersView: View {
    @EnvironmentObject var authService: AuthService
    @State private var blockedUsers: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if blockedUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("ブロック中のユーザーはいません")
                        .foregroundColor(.secondary)
                }
            } else {
                List(blockedUsers) { user in
                    HStack {
                        ProfileAvatarView(user: user, size: 40)
                        
                        VStack(alignment: .leading) {
                            Text(user.displayName)
                                .font(.headline)
                            Text("@\(user.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("解除") {
                            unblockUser(user)
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                }
            }
        }
        .navigationTitle("ブロック中のユーザー")
        .task {
            await loadBlockedUsers()
        }
    }
    
    private func loadBlockedUsers() async {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            blockedUsers = try await BlockReportService.shared.fetchBlockedUsers(blockerId: userId)
        } catch {
            print("🔴 [BlockedUsers] 取得エラー: \(error)")
        }
        isLoading = false
    }
    
    private func unblockUser(_ user: User) {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            do {
                try await BlockReportService.shared.unblockUser(blockerId: currentUserId, blockedId: user.id)
                await MainActor.run {
                    blockedUsers.removeAll { $0.id == user.id }
                }
            } catch {
                print("🔴 [BlockedUsers] ブロック解除エラー: \(error)")
            }
        }
    }
}

// MARK: - ヘルプ
struct HelpView: View {
    var body: some View {
        List {
            NavigationLink("よくある質問") {
                Text("FAQ")
                    .navigationTitle("よくある質問")
            }
            NavigationLink("お問い合わせ") {
                Text("Contact")
                    .navigationTitle("お問い合わせ")
            }
        }
        .navigationTitle("ヘルプ")
    }
}

// MARK: - 利用規約
struct TermsView: View {
    var body: some View {
        ScrollView {
            Text("利用規約の内容がここに表示されます。")
                .padding()
        }
        .navigationTitle("利用規約")
    }
}

// MARK: - プライバシーポリシー
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("プライバシーポリシーの内容がここに表示されます。")
                .padding()
        }
        .navigationTitle("プライバシーポリシー")
    }
}

// MARK: - アイコン縁色設定
struct IconBorderColorSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedColor: Color = .purple
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false

    private var canChangeColor: Bool {
        guard let changedAt = authService.currentUser?.iconBorderChangedAt else {
            return true // 一度も変更していない場合はOK
        }
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return changedAt <= oneYearAgo
    }

    private var nextChangeDate: Date? {
        guard let changedAt = authService.currentUser?.iconBorderChangedAt else { return nil }
        return Calendar.current.date(byAdding: .year, value: 1, to: changedAt)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    // プレビュー
                    ZStack {
                        Circle()
                            .stroke(selectedColor, lineWidth: 3)
                            .frame(width: 86, height: 86)

                        ProfileAvatarView(user: authService.currentUser, size: 80)
                    }

                    Text("相互フォローの相手に表示されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section("色を選択") {
                if canChangeColor {
                    ColorPicker("縁色", selection: $selectedColor, supportsOpacity: false)
                        .padding(.vertical, 8)

                    // プリセットカラー
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(presetColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                    HapticManager.shared.lightImpact()
                                }
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("変更できません")
                                .font(.headline)
                            if let nextDate = nextChangeDate {
                                Text("次回変更可能日: \(formatDate(nextDate))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            if canChangeColor {
                Section {
                    Button(action: saveColor) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("保存")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                } footer: {
                    Text("縁色は1年に1回のみ変更できます")
                        .font(.caption)
                }
            }

            Section {
                Button(role: .destructive, action: removeColor) {
                    HStack {
                        Spacer()
                        Text("縁色を削除")
                        Spacer()
                    }
                }
                .disabled(isSaving || authService.currentUser?.iconBorderColor == nil)
            }
        }
        .navigationTitle("アイコン縁色")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let colorHex = authService.currentUser?.iconBorderColor {
                selectedColor = Color(hex: colorHex) ?? .purple
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("保存完了", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("アイコン縁色を更新しました")
        }
    }

    private var presetColors: [Color] {
        [.purple, .pink, .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo]
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func saveColor() {
        guard let userId = authService.currentUser?.id else { return }

        isSaving = true

        Task {
            do {
                let hexColor = selectedColor.toHex()
                try await UserService.shared.updateIconBorderColor(userId: userId, color: hexColor)
                await MainActor.run {
                    authService.currentUser?.iconBorderColor = hexColor
                    authService.currentUser?.iconBorderChangedAt = Date()
                    isSaving = false
                    showSuccessAlert = true
                    HapticManager.shared.success()
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

    private func removeColor() {
        guard let userId = authService.currentUser?.id else { return }

        isSaving = true

        Task {
            do {
                try await UserService.shared.updateIconBorderColor(userId: userId, color: nil)
                await MainActor.run {
                    authService.currentUser?.iconBorderColor = nil
                    isSaving = false
                    HapticManager.shared.success()
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

// MARK: - Color Extension for toHex
extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#FFFFFF"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
