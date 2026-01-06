// Views/Collaboration/CollaborationWorkspaceView.swift

import SwiftUI

struct CollaborationWorkspaceView: View {
    let collaboration: Collaboration

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var currentCollaboration: Collaboration
    @State private var isLoading = false
    @State private var showModeSelection = false
    @State private var showCancelAlert = false
    @State private var showCompleteAlert = false

    // 編集用
    @State private var nodes: [Node] = []
    @State private var connections: [NodeConnection] = []
    @State private var centerNodeText: String = ""

    init(collaboration: Collaboration) {
        self.collaboration = collaboration
        _currentCollaboration = State(initialValue: collaboration)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if isLoading {
                    ProgressView("読み込み中...")
                } else {
                    VStack(spacing: 0) {
                        // メンバーバー
                        CollaborationMembersBar(members: currentCollaboration.members ?? [])
                            .padding(.horizontal)
                            .padding(.vertical, 8)

                        Divider()

                        // メインコンテンツ
                        if currentCollaboration.status == .pending {
                            // 招待待ち状態
                            PendingStateView(
                                collaboration: currentCollaboration,
                                onStartPressed: { showModeSelection = true },
                                isInviter: isInviter
                            )
                        } else if currentCollaboration.status == .active {
                            // アクティブな編集状態
                            ActiveWorkspaceView(
                                collaboration: currentCollaboration,
                                nodes: $nodes,
                                connections: $connections,
                                centerNodeText: $centerNodeText
                            )
                            .environmentObject(authService)
                        } else {
                            // 完了/キャンセル状態
                            CompletedStateView(collaboration: currentCollaboration)
                        }
                    }
                }
            }
            .navigationTitle("共同編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                    }
                }

                if isInviter && currentCollaboration.status == .pending {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("キャンセル", role: .destructive) {
                            showCancelAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }

                if isInviter && currentCollaboration.status == .active {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("投稿") {
                            showCompleteAlert = true
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showModeSelection) {
                ModeSelectionSheet(
                    onStart: { mode, theme, duration in
                        Task {
                            await startCollaboration(mode: mode, theme: theme, duration: duration)
                        }
                    }
                )
            }
            .alert("共同編集をキャンセル", isPresented: $showCancelAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("共同編集を終了", role: .destructive) {
                    Task { await cancelCollaboration() }
                }
            } message: {
                Text("この共同編集セッションをキャンセルしますか？全員の編集内容が削除されます。")
            }
            .alert("投稿する", isPresented: $showCompleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("投稿") {
                    Task { await completeAndPost() }
                }
            } message: {
                Text("共同編集を完了し、マインドマップを投稿しますか？")
            }
            .task {
                await loadCollaborationDetail()
            }
        }
    }

    private var isInviter: Bool {
        authService.currentUser?.id == currentCollaboration.inviterId
    }

    private var allMembersAccepted: Bool {
        currentCollaboration.members?.allSatisfy { $0.accepted } ?? false
    }

    private func loadCollaborationDetail() async {
        isLoading = true
        do {
            let detail = try await CollaborationService.shared.fetchCollaborationDetail(id: collaboration.id)
            await MainActor.run {
                currentCollaboration = detail
                isLoading = false
            }
        } catch {
            print("🔴 [Workspace] 詳細取得エラー: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func startCollaboration(mode: CollaborationMode, theme: String?, duration: Int?) async {
        do {
            try await CollaborationService.shared.startCollaboration(
                id: currentCollaboration.id,
                mode: mode,
                theme: theme,
                duration: duration
            )

            // テーマがあればセンターノードに設定
            if let theme = theme {
                await MainActor.run {
                    centerNodeText = theme
                }
            }

            await loadCollaborationDetail()
        } catch {
            print("🔴 [Workspace] 開始エラー: \(error)")
        }
    }

    private func cancelCollaboration() async {
        do {
            try await CollaborationService.shared.deleteCollaboration(id: currentCollaboration.id)
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("🔴 [Workspace] キャンセルエラー: \(error)")
        }
    }

    private func completeAndPost() async {
        guard let userId = authService.currentUser?.id else { return }

        do {
            // 共同編集を完了状態に
            try await CollaborationService.shared.completeCollaboration(id: currentCollaboration.id)

            // 投稿を作成
            var post = Post(
                userId: userId,
                centerNodeText: centerNodeText.isEmpty ? "共同編集マップ" : centerNodeText,
                collaborationId: currentCollaboration.id
            )
            post.nodes = nodes
            post.connections = connections

            try await PostService.shared.createPost(post: post)

            await MainActor.run {
                dismiss()
            }
        } catch {
            print("🔴 [Workspace] 投稿エラー: \(error)")
        }
    }
}

// MARK: - メンバーバー
struct CollaborationMembersBar: View {
    let members: [CollaborationMember]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(members) { member in
                VStack(spacing: 4) {
                    if let user = member.user {
                        ProfileAvatarView(user: user, size: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: member.borderColor) ?? .purple, lineWidth: 3)
                            )
                            .overlay(
                                // 承認状態インジケーター
                                Circle()
                                    .fill(member.accepted ? Color.green : Color.orange)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Image(systemName: member.accepted ? "checkmark" : "clock")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 14, y: 14)
                            )

                        Text(user.displayName.prefix(4))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // メンバー数
            Text("\(members.filter { $0.accepted }.count)/\(members.count) 参加中")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 招待待ち状態View
struct PendingStateView: View {
    let collaboration: Collaboration
    let onStartPressed: () -> Void
    let isInviter: Bool

    var allMembersAccepted: Bool {
        collaboration.members?.allSatisfy { $0.accepted } ?? false
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.2.wave.2")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.6))

            Text("メンバーの承認を待っています")
                .font(.title3)
                .fontWeight(.semibold)

            // 承認状況
            VStack(spacing: 8) {
                ForEach(collaboration.members ?? []) { member in
                    HStack {
                        if let user = member.user {
                            ProfileAvatarView(user: user, size: 32)
                            Text(user.displayName)
                                .font(.subheadline)
                        }

                        Spacer()

                        if member.accepted {
                            Label("承認済み", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("承認待ち", systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            if isInviter {
                Button(action: onStartPressed) {
                    Text("編集を開始")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(allMembersAccepted ? Color.purple : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!allMembersAccepted)
                .padding(.horizontal)

                if !allMembersAccepted {
                    Text("全員が承認すると編集を開始できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("招待者が編集を開始するのを待っています")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
                .frame(height: 40)
        }
    }
}

// MARK: - アクティブ編集View
struct ActiveWorkspaceView: View {
    let collaboration: Collaboration
    @Binding var nodes: [Node]
    @Binding var connections: [NodeConnection]
    @Binding var centerNodeText: String

    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(spacing: 0) {
            // モード表示
            HStack {
                if let mode = collaboration.mode {
                    Label(mode.displayName, systemImage: mode == .realtime ? "bolt.fill" : "eye.slash.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(mode == .realtime ? Color.green : Color.orange)
                        .cornerRadius(12)
                }

                if let theme = collaboration.initialTheme {
                    Text("テーマ: \(theme)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if collaboration.mode == .blind, let endsAt = collaboration.endsAt {
                    BlindModeTimer(endsAt: endsAt)
                }
            }
            .padding()

            // マインドマップエディター（簡易版）
            CollaborationMindMapEditor(
                nodes: $nodes,
                connections: $connections,
                centerNodeText: $centerNodeText,
                collaboration: collaboration,
                currentUserId: authService.currentUser?.id
            )
        }
    }
}

// MARK: - ブラインドモードタイマー
struct BlindModeTimer: View {
    let endsAt: Date
    @State private var remainingTime: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
            Text(timeString)
        }
        .font(.caption)
        .foregroundColor(remainingTime < 60 ? .red : .secondary)
        .onReceive(timer) { _ in
            remainingTime = max(0, endsAt.timeIntervalSinceNow)
        }
        .onAppear {
            remainingTime = max(0, endsAt.timeIntervalSinceNow)
        }
    }

    private var timeString: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 完了状態View
struct CompletedStateView: View {
    let collaboration: Collaboration

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: collaboration.status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(collaboration.status == .completed ? .green : .gray)

            Text(collaboration.status == .completed ? "共同編集が完了しました" : "共同編集がキャンセルされました")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()
        }
    }
}

// MARK: - モード選択シート
struct ModeSelectionSheet: View {
    let onStart: (CollaborationMode, String?, Int?) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var selectedMode: CollaborationMode = .realtime
    @State private var theme: String = ""
    @State private var duration: Int = 5

    let durationOptions = [3, 5, 10, 15, 30]

    var body: some View {
        NavigationStack {
            Form {
                Section("編集モード") {
                    ForEach(CollaborationMode.allCases, id: \.self) { mode in
                        Button(action: { selectedMode = mode }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: mode == .realtime ? "bolt.fill" : "eye.slash.fill")
                                            .foregroundColor(mode == .realtime ? .green : .orange)
                                        Text(mode.displayName)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    }
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }

                if selectedMode == .blind {
                    Section("ブラインドモード設定") {
                        TextField("テーマ（任意）", text: $theme)

                        Picker("制限時間", selection: $duration) {
                            ForEach(durationOptions, id: \.self) { min in
                                Text("\(min)分").tag(min)
                            }
                        }
                    }
                }
            }
            .navigationTitle("モード選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("開始") {
                        let finalTheme = selectedMode == .blind && !theme.isEmpty ? theme : nil
                        let finalDuration = selectedMode == .blind ? duration : nil
                        onStart(selectedMode, finalTheme, finalDuration)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 共同編集マインドマップエディター（簡易版）
struct CollaborationMindMapEditor: View {
    @Binding var nodes: [Node]
    @Binding var connections: [NodeConnection]
    @Binding var centerNodeText: String
    let collaboration: Collaboration
    let currentUserId: UUID?

    @State private var showAddNode = false
    @State private var newNodeText = ""
    @State private var selectedParentNode: Node?

    var currentMemberColor: String {
        collaboration.members?.first { $0.userId == currentUserId }?.borderColor ?? "#9333EA"
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)

            if nodes.isEmpty && centerNodeText.isEmpty {
                // 空の状態
                VStack(spacing: 16) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 50))
                        .foregroundColor(.purple.opacity(0.5))

                    Text("マインドマップを作成しましょう")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Button(action: { showAddNode = true }) {
                        Label("最初のノードを追加", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            } else {
                // マインドマップ表示
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        // センターノード
                        if !centerNodeText.isEmpty {
                            CollabNodeView(
                                text: centerNodeText,
                                isCenter: true,
                                borderColor: currentMemberColor
                            )
                            .position(x: 200, y: 200)
                        }

                        // 他のノード
                        ForEach(nodes) { node in
                            CollabNodeView(
                                text: node.text,
                                isCenter: false,
                                borderColor: collaboration.members?.first { $0.userId == node.contributorId }?.borderColor ?? currentMemberColor
                            )
                            .position(x: CGFloat(node.positionX), y: CGFloat(node.positionY))
                        }
                    }
                    .frame(width: 600, height: 600)
                }

                // 追加ボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showAddNode = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.purple)
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showAddNode) {
            AddCollabNodeSheet(
                onAdd: { text in
                    addNode(text: text)
                },
                isCenter: centerNodeText.isEmpty
            )
        }
    }

    private func addNode(text: String) {
        if centerNodeText.isEmpty {
            centerNodeText = text
        } else {
            let newNode = Node(
                postId: UUID(), // 仮のID
                text: text,
                positionX: Double.random(in: 100...300),
                positionY: Double.random(in: 100...300),
                contributorId: currentUserId
            )
            nodes.append(newNode)
        }
    }
}

// MARK: - 共同編集ノードView
struct CollabNodeView: View {
    let text: String
    let isCenter: Bool
    let borderColor: String

    var body: some View {
        Text(text)
            .font(isCenter ? .headline : .subheadline)
            .padding(isCenter ? 16 : 12)
            .background(
                isCenter ?
                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .top, endPoint: .bottom)
            )
            .foregroundColor(isCenter ? .white : .primary)
            .cornerRadius(isCenter ? 30 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: isCenter ? 30 : 12)
                    .stroke(Color(hex: borderColor) ?? .purple, lineWidth: 3)
            )
    }
}

// MARK: - ノード追加シート
struct AddCollabNodeSheet: View {
    let onAdd: (String) -> Void
    let isCenter: Bool

    @Environment(\.dismiss) var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(isCenter ? "中央ノード（テーマ）" : "新しいノード") {
                    TextField(isCenter ? "テーマを入力" : "ノードのテキスト", text: $text)
                }
            }
            .navigationTitle(isCenter ? "テーマを設定" : "ノードを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        onAdd(text)
                        dismiss()
                    }
                    .disabled(text.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}
