// Views/Main/Search/SearchView.swift

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var authService: AuthService
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var postResults: [Post] = []
    @State private var userResults: [User] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("ノードやユーザーを検索...", text: $searchText)
                        .autocapitalization(.none)
                        .onSubmit {
                            print("🔍 [SearchView] onSubmit triggered, searchText: '\(searchText)'")
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            print("🔍 [SearchView] Clear button tapped")
                            searchText = ""
                            postResults = []
                            userResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding()
                
                // タブ切り替え
                if !searchText.isEmpty {
                    Picker("検索対象", selection: $selectedTab) {
                        Text("投稿").tag(0)
                        Text("ユーザー").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedTab) { oldValue, newValue in
                        print("🔍 [SearchView] Tab changed: \(oldValue) -> \(newValue)")
                    }
                }
                
                // 検索結果
                if isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if searchText.isEmpty {
                    // 検索前の状態
                    TrendingView()
                } else if selectedTab == 0 {
                    // 投稿検索結果
                    PostSearchResults(posts: postResults)
                } else {
                    // ユーザー検索結果
                    UserSearchResults(users: userResults)
                }
            }
            .navigationTitle("検索")
            .onAppear {
                print("🔍 [SearchView] View appeared")
            }
            .onChange(of: searchText) { oldValue, newValue in
                print("🔍 [SearchView] searchText changed: '\(oldValue)' -> '\(newValue)'")
                if newValue.isEmpty {
                    postResults = []
                    userResults = []
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            print("🔴 [SearchView] performSearch aborted: searchText is empty")
            return
        }
        
        print("🔍 [SearchView] ========== SEARCH START ==========")
        print("🔍 [SearchView] Query: '\(searchText)'")
        print("🔍 [SearchView] Selected tab: \(selectedTab == 0 ? "投稿" : "ユーザー")")
        
        isSearching = true
        
        Task {
            let startTime = Date()
            
            do {
                // 投稿検索
                print("🔍 [SearchView] Starting post search...")
                let postStartTime = Date()
                postResults = try await PostService.shared.searchByNodeText(query: searchText)
                let postDuration = Date().timeIntervalSince(postStartTime)
                print("✅ [SearchView] Post search completed in \(String(format: "%.2f", postDuration))s")
                print("✅ [SearchView] Post results count: \(postResults.count)")
                
                if !postResults.isEmpty {
                    print("✅ [SearchView] Post results preview:")
                    for (index, post) in postResults.prefix(3).enumerated() {
                        print("   [\(index)] id: \(post.id), centerNode: '\(post.centerNodeText)', user: \(post.user?.username ?? "nil")")
                    }
                    if postResults.count > 3 {
                        print("   ... and \(postResults.count - 3) more")
                    }
                }
                
                // ユーザー検索
                print("🔍 [SearchView] Starting user search...")
                let userStartTime = Date()
                userResults = try await UserService.shared.searchUsers(query: searchText)
                let userDuration = Date().timeIntervalSince(userStartTime)
                print("✅ [SearchView] User search completed in \(String(format: "%.2f", userDuration))s")
                print("✅ [SearchView] User results count: \(userResults.count)")
                
                if !userResults.isEmpty {
                    print("✅ [SearchView] User results preview:")
                    for (index, user) in userResults.prefix(3).enumerated() {
                        print("   [\(index)] id: \(user.id), username: @\(user.username), displayName: '\(user.displayName)'")
                    }
                    if userResults.count > 3 {
                        print("   ... and \(userResults.count - 3) more")
                    }
                }
                
                let totalDuration = Date().timeIntervalSince(startTime)
                print("✅ [SearchView] ========== SEARCH COMPLETE ==========")
                print("✅ [SearchView] Total duration: \(String(format: "%.2f", totalDuration))s")
                
            } catch let error as NSError {
                print("🔴 [SearchView] ========== SEARCH ERROR ==========")
                print("🔴 [SearchView] Error domain: \(error.domain)")
                print("🔴 [SearchView] Error code: \(error.code)")
                print("🔴 [SearchView] Error description: \(error.localizedDescription)")
                print("🔴 [SearchView] Error userInfo: \(error.userInfo)")
                
                if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
                    print("🔴 [SearchView] Underlying error: \(underlyingError)")
                }
                
                if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                    print("🔴 [SearchView] Failure reason: \(reason)")
                }
                
                if let suggestion = error.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String {
                    print("🔴 [SearchView] Recovery suggestion: \(suggestion)")
                }
                
                // DecodingError の詳細
                if let decodingError = error.userInfo[NSUnderlyingErrorKey] as? DecodingError {
                    printDecodingError(decodingError)
                }
                
            } catch DecodingError.keyNotFound(let key, let context) {
                print("🔴 [SearchView] ========== DECODING ERROR: keyNotFound ==========")
                print("🔴 [SearchView] Missing key: '\(key.stringValue)'")
                print("🔴 [SearchView] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("🔴 [SearchView] Debug description: \(context.debugDescription)")
                
            } catch DecodingError.typeMismatch(let type, let context) {
                print("🔴 [SearchView] ========== DECODING ERROR: typeMismatch ==========")
                print("🔴 [SearchView] Expected type: \(type)")
                print("🔴 [SearchView] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("🔴 [SearchView] Debug description: \(context.debugDescription)")
                
            } catch DecodingError.valueNotFound(let type, let context) {
                print("🔴 [SearchView] ========== DECODING ERROR: valueNotFound ==========")
                print("🔴 [SearchView] Expected type: \(type)")
                print("🔴 [SearchView] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("🔴 [SearchView] Debug description: \(context.debugDescription)")
                
            } catch DecodingError.dataCorrupted(let context) {
                print("🔴 [SearchView] ========== DECODING ERROR: dataCorrupted ==========")
                print("🔴 [SearchView] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("🔴 [SearchView] Debug description: \(context.debugDescription)")
                
            } catch let urlError as URLError {
                print("🔴 [SearchView] ========== URL ERROR ==========")
                print("🔴 [SearchView] Error code: \(urlError.code.rawValue)")
                print("🔴 [SearchView] Error description: \(urlError.localizedDescription)")
                print("🔴 [SearchView] Failing URL: \(urlError.failingURL?.absoluteString ?? "nil")")
                
                switch urlError.code {
                case .notConnectedToInternet:
                    print("🔴 [SearchView] Cause: Not connected to internet")
                case .timedOut:
                    print("🔴 [SearchView] Cause: Request timed out")
                case .cannotFindHost:
                    print("🔴 [SearchView] Cause: Cannot find host")
                case .cannotConnectToHost:
                    print("🔴 [SearchView] Cause: Cannot connect to host")
                case .networkConnectionLost:
                    print("🔴 [SearchView] Cause: Network connection lost")
                case .badServerResponse:
                    print("🔴 [SearchView] Cause: Bad server response")
                default:
                    print("🔴 [SearchView] Cause: Other URL error")
                }
                
            } catch {
                print("🔴 [SearchView] ========== UNKNOWN ERROR ==========")
                print("🔴 [SearchView] Error type: \(type(of: error))")
                print("🔴 [SearchView] Error description: \(error.localizedDescription)")
                print("🔴 [SearchView] Full error: \(error)")
            }
            
            isSearching = false
            print("🔍 [SearchView] isSearching set to false")
        }
    }
    
    private func printDecodingError(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            print("🔴 [SearchView] DecodingError.keyNotFound:")
            print("   Key: '\(key.stringValue)'")
            print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("   Description: \(context.debugDescription)")
        case .typeMismatch(let type, let context):
            print("🔴 [SearchView] DecodingError.typeMismatch:")
            print("   Expected: \(type)")
            print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("   Description: \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            print("🔴 [SearchView] DecodingError.valueNotFound:")
            print("   Expected: \(type)")
            print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("   Description: \(context.debugDescription)")
        case .dataCorrupted(let context):
            print("🔴 [SearchView] DecodingError.dataCorrupted:")
            print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("   Description: \(context.debugDescription)")
        @unknown default:
            print("🔴 [SearchView] DecodingError: Unknown case")
        }
    }
}

// MARK: - トレンド表示
struct TrendingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 人気のテーマ
                VStack(alignment: .leading, spacing: 12) {
                    Text("人気のテーマ")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            TrendingTagView(tag: "アニメ")
                            TrendingTagView(tag: "映画")
                            TrendingTagView(tag: "音楽")
                            TrendingTagView(tag: "ゲーム")
                            TrendingTagView(tag: "本")
                        }
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                // 検索のヒント
                VStack(spacing: 16) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.purple.opacity(0.5))
                    
                    Text("興味を検索してみましょう")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("ノードのテキストやユーザー名で\n検索できます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            .padding(.top)
        }
        .onAppear {
            print("🔍 [TrendingView] View appeared")
        }
    }
}

// MARK: - トレンドタグ
struct TrendingTagView: View {
    let tag: String
    
    var body: some View {
        Text(tag)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(20)
            .onTapGesture {
                print("🔍 [TrendingTagView] Tag tapped: '\(tag)'")
            }
    }
}

// MARK: - 投稿検索結果
struct PostSearchResults: View {
    let posts: [Post]
    
    var body: some View {
        Group {
            if posts.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("投稿が見つかりませんでした")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(posts) { post in
                            NavigationLink(destination: PostDetailView(post: post)) {
                                SearchPostCard(post: post)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            print("🔍 [PostSearchResults] View appeared with \(posts.count) posts")
        }
    }
}

// MARK: - 検索結果の投稿カード
struct SearchPostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ユーザー情報
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(post.user?.displayName.prefix(1) ?? "?"))
                            .font(.caption)
                            .foregroundColor(.white)
                    )
                
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
            }
            
            // 中心ノード
            HStack {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 10, height: 10)
                Text(post.centerNodeText)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // ノード一覧
            if let nodes = post.nodes?.filter({ !$0.isCenter }).prefix(3) {
                HStack(spacing: 8) {
                    ForEach(Array(nodes)) { node in
                        Text(node.text)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // 統計
            HStack(spacing: 16) {
                Label("\(post.likeCount)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.right")
                Label("\(post.nodes?.count ?? 0) ノード", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            print("🔍 [SearchPostCard] Card appeared for post: \(post.id)")
        }
    }
}

// MARK: - ユーザー検索結果
struct UserSearchResults: View {
    let users: [User]
    
    var body: some View {
        Group {
            if users.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("ユーザーが見つかりませんでした")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(users) { user in
                    NavigationLink(destination: UserProfileView(userId: user.id)) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(user.displayName.prefix(1)))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(user.totalBranches) 枝")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            print("🔍 [UserSearchResults] View appeared with \(users.count) users")
        }
    }
}
