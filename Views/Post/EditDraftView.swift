// Views/Post/EditDraftView.swift

import SwiftUI

struct EditDraftView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var draftManager = DraftManager.shared
    
    @State var draft: DraftPost
    @State private var showPostAlert = false
    @State private var showSaveAlert = false
    @State private var showServerLimitAlert = false
    @State private var isPosting = false
    @State private var showAddNode = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // マインドマップ表示
                DraftMindMapView(draft: $draft)
                
                // ノード追加ボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showAddNode = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.purple)
                                .shadow(radius: 4)
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("下書き編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // 下書き保存ボタン
                    Button("保存") {
                        saveDraft()
                    }
                    .foregroundColor(.orange)
                    
                    // 投稿ボタン
                    Button("投稿") {
                        if draftManager.canSaveToServer() {
                            showPostAlert = true
                        } else {
                            showServerLimitAlert = true
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.centerNodeText.isEmpty || isPosting)
                }
            }
            .alert("投稿しますか？", isPresented: $showPostAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("投稿") {
                    postToServer()
                }
            } message: {
                Text("この下書きを投稿します。今月の残り投稿数: \(draftManager.remainingServerSaves)回")
            }
            .alert("保存しました", isPresented: $showSaveAlert) {
                Button("OK") {}
            }
            .alert("月間投稿上限", isPresented: $showServerLimitAlert) {
                Button("OK") {}
            } message: {
                Text("今月の投稿上限（3回）に達しました。来月までお待ちください。")
            }
            .sheet(isPresented: $showAddNode) {
                AddDraftNodeSheet(draft: $draft)
            }
        }
    }
    
    private func saveDraft() {
        draft.updatedAt = Date()
        _ = draftManager.saveDraft(draft)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        showSaveAlert = true
    }
    
    private func postToServer() {
        guard let userId = authService.currentUser?.id else { return }
        
        isPosting = true
        
        Task {
            do {
                // ノードをNodeInput形式に変換
                let nodeInputs = draft.nodes.map { node in
                    NodeInput(
                        localId: node.id.uuidString,
                        text: node.isCenter ? draft.centerNodeText : node.text,
                        positionX: node.positionX,
                        positionY: node.positionY,
                        isCenter: node.isCenter
                    )
                }
                
                // コネクションをConnectionInput形式に変換
                let connectionInputs = draft.connections.map { conn in
                    ConnectionInput(
                        fromLocalId: conn.fromNodeId.uuidString,
                        toLocalId: conn.toNodeId.uuidString,
                        reason: nil
                    )
                }
                
                // 投稿を作成
                _ = try await PostService.shared.createPost(
                    userId: userId,
                    centerNodeText: draft.centerNodeText,
                    nodes: nodeInputs,
                    connections: connectionInputs
                )
                
                // 下書きを削除
                draftManager.deleteDraft(id: draft.id)
                
                // サーバー保存カウントを増加
                draftManager.incrementServerSaveCount()
                
                // 投稿作成通知
                NotificationCenter.default.post(name: .postCreated, object: nil)
                
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    dismiss()
                }
            } catch {
                print("🔴 [EditDraft] 投稿エラー: \(error)")
                await MainActor.run {
                    isPosting = false
                }
            }
        }
    }
}

// MARK: - 下書きマインドマップ表示
struct DraftMindMapView: View {
    @Binding var draft: DraftPost
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                // 接続線
                ForEach(draft.connections) { connection in
                    DraftConnectionLine(connection: connection, nodes: draft.nodes)
                }
                
                // ノード
                ForEach(draft.nodes) { node in
                    DraftNodeView(
                        node: node,
                        centerText: draft.centerNodeText,
                        onDelete: {
                            deleteNode(node)
                        }
                    )
                }
                
                // 中央ノードがない場合
                if draft.nodes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("右下の＋ボタンでノードを追加")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func deleteNode(_ node: DraftNode) {
        // 接続も削除
        draft.connections.removeAll { $0.fromNodeId == node.id || $0.toNodeId == node.id }
        draft.nodes.removeAll { $0.id == node.id }
    }
}

// MARK: - 下書きノード表示
struct DraftNodeView: View {
    let node: DraftNode
    let centerText: String
    var onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    var nodeSize: CGFloat {
        node.isCenter ? 120 : 90
    }
    
    var displayText: String {
        node.isCenter ? centerText : node.text
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    node.isCenter
                        ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            if !node.isCenter {
                Circle()
                    .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                    .frame(width: nodeSize, height: nodeSize)
            }
            
            Text(displayText.isEmpty ? "テーマを入力" : displayText)
                .font(.system(size: node.isCenter ? 14 : 12))
                .fontWeight(node.isCenter ? .bold : .medium)
                .foregroundColor(node.isCenter ? .white : (displayText.isEmpty ? .secondary : .primary))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(width: nodeSize - 16)
        }
        .position(x: node.positionX, y: node.positionY)
        .onLongPressGesture {
            if !node.isCenter {
                showDeleteAlert = true
            }
        }
        .alert("ノードを削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - 下書き接続線
struct DraftConnectionLine: View {
    let connection: DraftConnection
    let nodes: [DraftNode]
    
    var body: some View {
        if let fromNode = nodes.first(where: { $0.id == connection.fromNodeId }),
           let toNode = nodes.first(where: { $0.id == connection.toNodeId }) {
            
            let fromPoint = CGPoint(x: fromNode.positionX, y: fromNode.positionY)
            let toPoint = CGPoint(x: toNode.positionX, y: toNode.positionY)
            
            let fromRadius: CGFloat = fromNode.isCenter ? 60 : 45
            let toRadius: CGFloat = toNode.isCenter ? 60 : 45
            
            let angle = atan2(toPoint.y - fromPoint.y, toPoint.x - fromPoint.x)
            let adjustedFromPoint = CGPoint(
                x: fromPoint.x + cos(angle) * fromRadius,
                y: fromPoint.y + sin(angle) * fromRadius
            )
            let adjustedToPoint = CGPoint(
                x: toPoint.x - cos(angle) * toRadius,
                y: toPoint.y - sin(angle) * toRadius
            )
            
            Path { path in
                path.move(to: adjustedFromPoint)
                path.addLine(to: adjustedToPoint)
            }
            .stroke(Color.purple.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

// MARK: - ノード追加シート
struct AddDraftNodeSheet: View {
    @Binding var draft: DraftPost
    @Environment(\.dismiss) var dismiss
    
    @State private var nodeText = ""
    @State private var reason = ""
    @State private var isCenterNode = false
    
    var body: some View {
        NavigationStack {
            Form {
                if draft.nodes.isEmpty || !draft.nodes.contains(where: { $0.isCenter }) {
                    Section {
                        Toggle("中央ノード（テーマ）として追加", isOn: $isCenterNode)
                    }
                }
                
                Section(isCenterNode ? "テーマ" : "ノードの内容") {
                    TextField(isCenterNode ? "例：転職について" : "例：給料を上げたい", text: $nodeText)
                }
                
                if !isCenterNode {
                    Section("理由（任意）") {
                        TextField("なぜこのノードを追加しますか？", text: $reason)
                    }
                }
            }
            .navigationTitle("ノードを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        addNode()
                    }
                    .fontWeight(.semibold)
                    .disabled(nodeText.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            // 中央ノードがない場合は自動的に中央ノードとして追加
            if !draft.nodes.contains(where: { $0.isCenter }) {
                isCenterNode = true
            }
        }
    }
    
    private func addNode() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        if isCenterNode {
            // 中央ノードを追加
            draft.centerNodeText = nodeText
            let centerNode = DraftNode(
                text: nodeText,
                positionX: screenWidth / 2,
                positionY: screenHeight / 2 - 50,
                isCenter: true
            )
            draft.nodes.append(centerNode)
        } else {
            // 通常ノードを追加
            let angle = Double.random(in: 0...(2 * .pi))
            let distance: CGFloat = 150
            let centerNode = draft.nodes.first(where: { $0.isCenter })
            let centerX = centerNode?.positionX ?? screenWidth / 2
            let centerY = centerNode?.positionY ?? screenHeight / 2 - 50
            
            let newNode = DraftNode(
                text: nodeText,
                reason: reason.isEmpty ? nil : reason,
                positionX: centerX + cos(angle) * distance,
                positionY: centerY + sin(angle) * distance,
                isCenter: false
            )
            draft.nodes.append(newNode)
            
            // 中央ノードとの接続を追加
            if let centerId = centerNode?.id {
                let connection = DraftConnection(fromNodeId: centerId, toNodeId: newNode.id)
                draft.connections.append(connection)
            }
        }
        
        dismiss()
    }
}
