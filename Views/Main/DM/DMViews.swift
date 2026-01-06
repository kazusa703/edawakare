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
            .task { await loadConversations() }
            .refreshable { await loadConversations() }
        }
    }
    
    private func loadConversations() async {
        guard let userId = authService.currentUser?.id else { return }
        isLoading = true
        conversations = (try? await MessageService.shared.fetchConversations(userId: userId)) ?? []
        isLoading = false
    }
    
    private func deleteConversation(at offsets: IndexSet) {
        for index in offsets {
            let conversation = conversations[index]
            Task {
                try? await MessageService.shared.deleteConversation(conversationId: conversation.id)
                await MainActor.run { conversations.remove(at: index) }
            }
        }
    }
}

// MARK: - 会話行
struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            InitialAvatarView(conversation.otherUser?.displayName ?? "?", size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUser?.displayName ?? "ユーザー")
                        .font(.headline)
                    Spacer()
                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(TimeFormatter.timeAgo(from: lastMessageAt))
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
                        withAnimation { proxy.scrollTo(lastMessage.id, anchor: .bottom) }
                    }
                }
            }
            
            Divider()
            MessageInputBar(text: $newMessageText, isSending: isSending, onSend: sendMessage)
        }
        .navigationTitle(conversation.otherUser?.displayName ?? "チャット")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMessages() }
    }
    
    private func loadMessages() async {
        isLoading = true
        messages = (try? await MessageService.shared.fetchMessages(conversationId: conversation.id)) ?? []
        if let userId = authService.currentUser?.id {
            try? await MessageService.shared.markAsRead(conversationId: conversation.id, userId: userId)
        }
        isLoading = false
    }
    
    private func sendMessage() {
        guard let userId = authService.currentUser?.id else { return }
        let text = newMessageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        isSending = true
        Task {
            let otherUserId = conversation.user1Id == userId ? conversation.user2Id : conversation.user1Id
            if let message = try? await MessageService.shared.sendMessage(
                conversationId: conversation.id,
                senderId: userId,
                receiverId: otherUserId,
                content: text
            ) {
                await MainActor.run {
                    messages.append(message)
                    newMessageText = ""
                }
            }
            await MainActor.run { isSending = false }
        }
    }
}

// MARK: - メッセージ入力バー
struct MessageInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void
    var placeholder: String = "メッセージを入力..."
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }
    
    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            
            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(canSend ? .purple : .gray)
                }
            }
            .disabled(!canSend)
        }
        .padding()
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
                        ? AppColors.primaryGradient
                        : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(isFromMe ? .white : .primary)
                    .cornerRadius(20)
                
                Text(TimeFormatter.timeOnly(from: message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromMe { Spacer() }
        }
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
                SearchBar(text: $searchText, placeholder: "ユーザーを検索...")
                    .onChange(of: searchText) { _, newValue in searchUsers(query: newValue) }
                    .padding()
                
                if isSearching {
                    ProgressView().padding()
                } else {
                    List(searchResults) { user in
                        Button(action: { startConversation(with: user) }) {
                            UserRowSimple(user: user)
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
            searchResults = ((try? await UserService.shared.searchUsers(query: query)) ?? [])
                .filter { $0.id != authService.currentUser?.id }
            isSearching = false
        }
    }
    
    private func startConversation(with user: User) {
        guard let myId = authService.currentUser?.id else { return }
        Task {
            _ = try? await MessageService.shared.createConversation(user1Id: myId, user2Id: user.id)
            await MainActor.run { dismiss() }
        }
    }
}

// MARK: - 検索バー
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "検索..."
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - シンプルユーザー行
struct UserRowSimple: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            InitialAvatarView(user.displayName, size: 40)
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
