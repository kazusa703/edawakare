// Views/Main/DM/DMViews.swift

import SwiftUI

// MARK: - DM一覧画面
struct DMListView: View {
    @EnvironmentObject var authService: AuthService
    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var showNewMessage = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && conversations.isEmpty {
                    ProgressView()
                } else if conversations.isEmpty {
                    EmptyDMView()
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(destination: ChatView(conversation: conversation)) {
                                ConversationRow(conversation: conversation)
                            }
                        }
                        .onDelete(perform: deleteConversation)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("メッセージ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewMessage = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewMessage) {
                NewMessageView()
                    .environmentObject(authService)
            }
            .task {
                await loadConversations()
            }
            .refreshable {
                await loadConversations()
            }
        }
    }
    
    private func loadConversations() async {
        guard let userId = authService.currentUser?.id else { return }
        isLoading = true
        do {
            conversations = try await MessageService.shared.fetchConversations(userId: userId)
        } catch {
            print("🔴 [DMListView] loadConversations error: \(error)")
        }
        isLoading = false
    }
    
    private func deleteConversation(at offsets: IndexSet) {
        for index in offsets {
            let conversation = conversations[index]
            Task {
                try? await MessageService.shared.deleteConversation(conversationId: conversation.id)
                await MainActor.run {
                    conversations.remove(at: index)
                }
            }
        }
    }
}

// MARK: - 会話行
struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // アバター
            Circle()
                .fill(
                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(conversation.otherUser?.displayName.prefix(1) ?? "?"))
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUser?.displayName ?? "ユーザー")
                        .font(.headline)
                    
                    Spacer()
                    
                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(timeAgoString(from: lastMessageAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("@\(conversation.otherUser?.username ?? "unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        
        if seconds < 60 {
            return "たった今"
        } else if seconds < 3600 {
            return "\(seconds / 60)分前"
        } else if seconds < 86400 {
            return "\(seconds / 3600)時間前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - チャット画面
struct ChatView: View {
    let conversation: Conversation
    @EnvironmentObject var authService: AuthService
    @State private var messages: [DMMessage] = []
    @State private var newMessageText = ""
    @State private var isLoading = false
    @State private var isSending = false
    
    var body: some View {
        VStack(spacing: 0) {
            // メッセージ一覧
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isFromMe: message.senderId == authService.currentUser?.id
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // 入力欄
            HStack(spacing: 12) {
                TextField("メッセージを入力...", text: $newMessageText)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    if isSending {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(
                                newMessageText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? .gray
                                : .purple
                            )
                    }
                }
                .disabled(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle(conversation.otherUser?.displayName ?? "チャット")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        do {
            messages = try await MessageService.shared.fetchMessages(conversationId: conversation.id)
            
            // 既読にする
            if let userId = authService.currentUser?.id {
                try? await MessageService.shared.markAsRead(conversationId: conversation.id, userId: userId)
            }
        } catch {
            print("🔴 [ChatView] loadMessages error: \(error)")
        }
        isLoading = false
    }
    
    private func sendMessage() {
        guard let userId = authService.currentUser?.id else { return }
        let text = newMessageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        isSending = true
        
        Task {
            do {
                // sendMessage を呼び出す前に otherUserId を計算
                let otherUserId = conversation.user1Id == userId ? conversation.user2Id : conversation.user1Id
                
                let message = try await MessageService.shared.sendMessage(
                    conversationId: conversation.id,
                    senderId: userId,
                    receiverId: otherUserId,
                    content: text
                )
                
                await MainActor.run {
                    messages.append(message)
                    newMessageText = ""
                    isSending = false
                }
            } catch {
                print("🔴 [DM] メッセージ送信エラー: \(error)")
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
}

// MARK: - メッセージバブル
struct MessageBubble: View {
    let message: DMMessage
    let isFromMe: Bool
    
    var body: some View {
        HStack {
            if isFromMe { Spacer() }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isFromMe
                        ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(isFromMe ? .white : .primary)
                    .cornerRadius(20)
                
                Text(timeString(from: message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromMe { Spacer() }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 空のDM画面
struct EmptyDMView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))
            
            Text("メッセージがありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("右上のボタンから新しいメッセージを送れます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - 新規メッセージ画面
struct NewMessageView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("ユーザーを検索...", text: $searchText)
                        .autocapitalization(.none)
                        .onChange(of: searchText) { _, newValue in
                            searchUsers(query: newValue)
                        }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding()
                
                // 検索結果
                if isSearching {
                    ProgressView()
                        .padding()
                } else {
                    List(searchResults) { user in
                        Button(action: { startConversation(with: user) }) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(
                                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(user.displayName.prefix(1)))
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
            }
            .navigationTitle("新規メッセージ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
    
    private func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        Task {
            do {
                searchResults = try await UserService.shared.searchUsers(query: query)
                // 自分自身を除外
                searchResults = searchResults.filter { $0.id != authService.currentUser?.id }
            } catch {
                print("🔴 [NewMessageView] searchUsers error: \(error)")
            }
            isSearching = false
        }
    }
    
    private func startConversation(with user: User) {
        guard let myId = authService.currentUser?.id else { return }
        
        Task {
            do {
                _ = try await MessageService.shared.createConversation(user1Id: myId, user2Id: user.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("🔴 [NewMessageView] startConversation error: \(error)")
            }
        }
    }
}
