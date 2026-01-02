// Views/Post/EditPostView.swift

import SwiftUI

struct EditPostView: View {
    let post: Post
    var onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var editMode: EditMode = .text
    @State private var nodes: [EditableNode] = []
    @State private var connections: [EditableConnection] = []
    @State private var existingNodeIds: Set<UUID> = []  // 既存ノードのID
    @State private var existingConnectionIds: Set<UUID> = []  // 既存コネクションのID
    
    @State private var selectedNodeId: UUID?
    @State private var selectedConnectionId: UUID?
    @State private var showEditSheet = false
    @State private var editingText = ""
    @State private var editingType: EditingType = .node
    @State private var showReasonPopup = false
    @State private var popupReason = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum EditMode: String, CaseIterable {
        case text = "テキスト"
        case visual = "ビジュアル"
    }
    
    enum EditingType {
        case node
        case connection
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // モード切り替え
                    Picker("編集モード", selection: $editMode) {
                        ForEach(EditMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // ツールバー（ビジュアルモード時）
                    if editMode == .visual {
                        EditVisualToolbar(
                            hasSelection: selectedNodeId != nil || selectedConnectionId != nil,
                            canDelete: canDeleteSelected,
                            onAdd: addChildNode,
                            onEdit: startEditing,
                            onDelete: deleteSelected
                        )
                    }
                    
                    // メインコンテンツ
                    if editMode == .text {
                        EditTextModeView(
                            centerNodeText: post.centerNodeText,
                            nodes: $nodes,
                            connections: $connections,
                            existingNodeIds: existingNodeIds,
                            existingConnectionIds: existingConnectionIds
                        )
                    } else {
                        EditVisualModeView(
                            centerNodeText: post.centerNodeText,
                            nodes: $nodes,
                            connections: $connections,
                            existingNodeIds: existingNodeIds,
                            selectedNodeId: $selectedNodeId,
                            selectedConnectionId: $selectedConnectionId,
                            onShowReason: { reason in
                                popupReason = reason
                                showReasonPopup = true
                            }
                        )
                    }
                }
                
                // 理由ポップアップ
                if showReasonPopup {
                    ReasonPopupView(
                        reason: popupReason,
                        onDismiss: { showReasonPopup = false }
                    )
                }
                
                // 保存中オーバーレイ
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("保存中...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
            .navigationTitle("ノードを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveChanges() }
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                        .disabled(isSaving || !hasChanges)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditTextSheet(
                    title: editingType == .node ? "ノードを編集" : "理由を編集",
                    text: $editingText,
                    onSave: saveEdit
                )
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadExistingData()
            }
        }
    }
    
    // MARK: - 変更があるかチェック
    private var hasChanges: Bool {
        let newNodes = nodes.filter { !existingNodeIds.contains($0.id) }
        let newConnections = connections.filter { !existingConnectionIds.contains($0.id) }
        return !newNodes.isEmpty || !newConnections.isEmpty
    }
    
    // MARK: - 選択中のアイテムを削除可能か
    private var canDeleteSelected: Bool {
        if let nodeId = selectedNodeId {
            // 既存ノードと中心ノードは削除不可
            if existingNodeIds.contains(nodeId) { return false }
            if let node = nodes.first(where: { $0.id == nodeId }), node.isCenter { return false }
            return true
        }
        if let connectionId = selectedConnectionId {
            // 既存コネクションは削除不可
            return !existingConnectionIds.contains(connectionId)
        }
        return false
    }
    
    // MARK: - 既存データを読み込み
    private func loadExistingData() {
        // 既存ノードをEditableNodeに変換
        if let postNodes = post.nodes {
            for node in postNodes {
                let editableNode = EditableNode(
                    id: node.id,
                    text: node.isCenter ? post.centerNodeText : node.text,
                    positionX: node.positionX,
                    positionY: node.positionY,
                    isCenter: node.isCenter,
                    parentId: nil
                )
                nodes.append(editableNode)
                existingNodeIds.insert(node.id)
            }
        }
        
        // 既存コネクションをEditableConnectionに変換
        if let postConnections = post.connections {
            for conn in postConnections {
                let editableConn = EditableConnection(
                    id: conn.id,
                    fromNodeId: conn.fromNodeId,
                    toNodeId: conn.toNodeId,
                    reason: conn.reason ?? ""
                )
                connections.append(editableConn)
                existingConnectionIds.insert(conn.id)
                
                // parentIdを設定
                if let index = nodes.firstIndex(where: { $0.id == conn.toNodeId }) {
                    nodes[index].parentId = conn.fromNodeId
                }
            }
        }
    }
    
    // MARK: - 子ノード追加
    private func addChildNode() {
        guard let parentId = selectedNodeId,
              let parentNode = nodes.first(where: { $0.id == parentId }) else { return }
        
        let angle = Double.random(in: 0...(2 * .pi))
        let distance: Double = 150
        let newX = parentNode.positionX + cos(angle) * distance
        let newY = parentNode.positionY + sin(angle) * distance
        
        let newNode = EditableNode(
            id: UUID(),
            text: "新しいノード",
            positionX: newX,
            positionY: newY,
            isCenter: false,
            parentId: parentId
        )
        
        let newConnection = EditableConnection(
            id: UUID(),
            fromNodeId: parentId,
            toNodeId: newNode.id,
            reason: ""
        )
        
        nodes.append(newNode)
        connections.append(newConnection)
        
        selectedNodeId = newNode.id
        selectedConnectionId = nil
        editingType = .node
        editingText = newNode.text
        showEditSheet = true
    }
    
    // MARK: - 編集開始
    private func startEditing() {
        if let nodeId = selectedNodeId {
            // 既存ノードは編集不可
            if existingNodeIds.contains(nodeId) { return }
            
            if let node = nodes.first(where: { $0.id == nodeId }) {
                editingText = node.text
                editingType = .node
                showEditSheet = true
            }
        } else if let connectionId = selectedConnectionId {
            // 既存コネクションの理由は編集可能
            if let connection = connections.first(where: { $0.id == connectionId }) {
                editingText = connection.reason
                editingType = .connection
                showEditSheet = true
            }
        }
    }
    
    // MARK: - 編集保存
    private func saveEdit() {
        if editingType == .node {
            if let nodeId = selectedNodeId,
               let index = nodes.firstIndex(where: { $0.id == nodeId }) {
                nodes[index].text = editingText
            }
        } else {
            if let connectionId = selectedConnectionId,
               let index = connections.firstIndex(where: { $0.id == connectionId }) {
                connections[index].reason = editingText
            }
        }
        showEditSheet = false
    }
    
    // MARK: - 削除
    private func deleteSelected() {
        if let nodeId = selectedNodeId {
            // 既存ノードは削除不可
            if existingNodeIds.contains(nodeId) { return }
            
            if let node = nodes.first(where: { $0.id == nodeId }), node.isCenter { return }
            
            deleteNodeAndDescendants(nodeId: nodeId)
            selectedNodeId = nil
        } else if let connectionId = selectedConnectionId {
            // 既存コネクションは削除不可
            if existingConnectionIds.contains(connectionId) { return }
            
            if let connection = connections.first(where: { $0.id == connectionId }) {
                deleteNodeAndDescendants(nodeId: connection.toNodeId)
            }
            selectedConnectionId = nil
        }
    }
    
    private func deleteNodeAndDescendants(nodeId: UUID) {
        // 既存ノードは削除しない
        if existingNodeIds.contains(nodeId) { return }
        
        let childConnections = connections.filter { $0.fromNodeId == nodeId }
        for conn in childConnections {
            deleteNodeAndDescendants(nodeId: conn.toNodeId)
        }
        connections.removeAll { $0.toNodeId == nodeId || $0.fromNodeId == nodeId }
        nodes.removeAll { $0.id == nodeId }
    }
    
    // MARK: - 変更を保存
    private func saveChanges() {
        isSaving = true
        
        Task {
            do {
                // 新規ノードのみを保存
                let newNodes = nodes.filter { !existingNodeIds.contains($0.id) }
                let newConnections = connections.filter { !existingConnectionIds.contains($0.id) }
                
                // ローカルID → サーバーID のマッピング
                var nodeIdMap: [UUID: UUID] = [:]
                
                // 既存ノードのIDはそのまま使用
                for nodeId in existingNodeIds {
                    nodeIdMap[nodeId] = nodeId
                }
                
                // 新規ノードを保存
                for node in newNodes {
                    let createdNode = try await PostService.shared.addNode(
                        postId: post.id,
                        text: node.text,
                        positionX: node.positionX,
                        positionY: node.positionY,
                        isCenter: false
                    )
                    nodeIdMap[node.id] = createdNode.id
                }
                
                // 新規コネクションを保存
                for conn in newConnections {
                    guard let fromId = nodeIdMap[conn.fromNodeId],
                          let toId = nodeIdMap[conn.toNodeId] else { continue }
                    
                    try await PostService.shared.addConnection(
                        postId: post.id,
                        fromNodeId: fromId,
                        toNodeId: toId,
                        reason: conn.reason.isEmpty ? nil : conn.reason
                    )
                }
                
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - 編集用ツールバー
struct EditVisualToolbar: View {
    let hasSelection: Bool
    let canDelete: Bool
    let onAdd: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Spacer()
            
            Button(action: onAdd) {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("追加")
                        .font(.caption2)
                }
            }
            .disabled(!hasSelection)
            .foregroundColor(hasSelection ? .purple : .gray)
            
            Button(action: onEdit) {
                VStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                    Text("編集")
                        .font(.caption2)
                }
            }
            .disabled(!hasSelection)
            .foregroundColor(hasSelection ? .purple : .gray)
            
            Button(action: onDelete) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                    Text("削除")
                        .font(.caption2)
                }
            }
            .disabled(!canDelete)
            .foregroundColor(canDelete ? .red : .gray)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - テキストモード（編集用）
struct EditTextModeView: View {
    let centerNodeText: String
    @Binding var nodes: [EditableNode]
    @Binding var connections: [EditableConnection]
    let existingNodeIds: Set<UUID>
    let existingConnectionIds: Set<UUID>
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 中心ノード（編集不可）
                EditCenterNodeRow(
                    text: centerNodeText,
                    onAddChild: { addChildToCenter() }
                )
                
                // 子ノードツリー
                let centerNode = nodes.first(where: { $0.isCenter })
                if let centerId = centerNode?.id {
                    EditChildNodesTree(
                        parentId: centerId,
                        nodes: $nodes,
                        connections: $connections,
                        existingNodeIds: existingNodeIds,
                        existingConnectionIds: existingConnectionIds,
                        level: 1
                    )
                }
            }
            .padding()
        }
    }
    
    private func addChildToCenter() {
        guard let centerNode = nodes.first(where: { $0.isCenter }) else { return }
        
        let angle = Double.random(in: 0...(2 * .pi))
        let distance: Double = 150
        let newX = centerNode.positionX + cos(angle) * distance
        let newY = centerNode.positionY + sin(angle) * distance
        
        let newNode = EditableNode(
            id: UUID(),
            text: "",
            positionX: newX,
            positionY: newY,
            isCenter: false,
            parentId: centerNode.id
        )
        
        let newConnection = EditableConnection(
            id: UUID(),
            fromNodeId: centerNode.id,
            toNodeId: newNode.id,
            reason: ""
        )
        
        nodes.append(newNode)
        connections.append(newConnection)
    }
}

// MARK: - 中心ノード行（編集用）
struct EditCenterNodeRow: View {
    let text: String
    let onAddChild: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 16, height: 16)
                
                Text(text)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 中心ノードは編集不可を示すアイコン
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onAddChild) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("枝を追加")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 子ノードツリー（編集用・再帰）
struct EditChildNodesTree: View {
    let parentId: UUID
    @Binding var nodes: [EditableNode]
    @Binding var connections: [EditableConnection]
    let existingNodeIds: Set<UUID>
    let existingConnectionIds: Set<UUID>
    let level: Int
    
    var childConnections: [EditableConnection] {
        connections.filter { $0.fromNodeId == parentId }
    }
    
    var body: some View {
        ForEach(childConnections) { connection in
            if let nodeIndex = nodes.firstIndex(where: { $0.id == connection.toNodeId }) {
                let isExistingNode = existingNodeIds.contains(nodes[nodeIndex].id)
                let isExistingConnection = existingConnectionIds.contains(connection.id)
                
                EditChildNodeRow(
                    node: $nodes[nodeIndex],
                    connection: Binding(
                        get: { connections.first(where: { $0.id == connection.id }) ?? connection },
                        set: { newValue in
                            if let idx = connections.firstIndex(where: { $0.id == connection.id }) {
                                connections[idx] = newValue
                            }
                        }
                    ),
                    level: level,
                    isExistingNode: isExistingNode,
                    isExistingConnection: isExistingConnection,
                    onAddChild: { addChild(to: nodes[nodeIndex].id) },
                    onDelete: { deleteNode(nodes[nodeIndex].id) }
                )
                
                EditChildNodesTree(
                    parentId: nodes[nodeIndex].id,
                    nodes: $nodes,
                    connections: $connections,
                    existingNodeIds: existingNodeIds,
                    existingConnectionIds: existingConnectionIds,
                    level: level + 1
                )
            }
        }
    }
    
    private func addChild(to parentId: UUID) {
        guard let parentNode = nodes.first(where: { $0.id == parentId }) else { return }
        
        let angle = Double.random(in: 0...(2 * .pi))
        let distance: Double = 120
        let newX = parentNode.positionX + cos(angle) * distance
        let newY = parentNode.positionY + sin(angle) * distance
        
        let newNode = EditableNode(
            id: UUID(),
            text: "",
            positionX: newX,
            positionY: newY,
            isCenter: false,
            parentId: parentId
        )
        
        let newConnection = EditableConnection(
            id: UUID(),
            fromNodeId: parentId,
            toNodeId: newNode.id,
            reason: ""
        )
        
        nodes.append(newNode)
        connections.append(newConnection)
    }
    
    private func deleteNode(_ nodeId: UUID) {
        // 既存ノードは削除不可
        if existingNodeIds.contains(nodeId) { return }
        
        let childConns = connections.filter { $0.fromNodeId == nodeId }
        for conn in childConns {
            deleteNode(conn.toNodeId)
        }
        connections.removeAll { $0.toNodeId == nodeId || $0.fromNodeId == nodeId }
        nodes.removeAll { $0.id == nodeId }
    }
}

// MARK: - 子ノード行（編集用）
struct EditChildNodeRow: View {
    @Binding var node: EditableNode
    @Binding var connection: EditableConnection
    let level: Int
    let isExistingNode: Bool
    let isExistingConnection: Bool
    let onAddChild: () -> Void
    let onDelete: () -> Void
    
    @State private var nodeText: String = ""
    @State private var reasonText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                // インデント + 矢印
                HStack(spacing: 0) {
                    ForEach(0..<level, id: \.self) { i in
                        if i == level - 1 {
                            HStack(spacing: 2) {
                                Rectangle()
                                    .fill(Color.purple.opacity(0.5))
                                    .frame(width: 16, height: 2)
                                Image(systemName: "arrowtriangle.right.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.purple.opacity(0.7))
                            }
                            .frame(width: 24)
                        } else {
                            Rectangle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 2, height: 50)
                                .padding(.leading, 8)
                                .padding(.trailing, 14)
                        }
                    }
                }
                
                // ノードアイコン（新規は緑、既存は紫）
                Circle()
                    .stroke(isExistingNode ? Color.purple : Color.green, lineWidth: 2)
                    .background(Circle().fill(isExistingNode ? Color.clear : Color.green.opacity(0.1)))
                    .frame(width: 14, height: 14)
                
                // テキスト入力（既存は編集不可）
                if isExistingNode {
                    Text(node.text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    TextField("ノード名を入力", text: $nodeText)
                        .font(.subheadline)
                        .onAppear { nodeText = node.text }
                        .onChange(of: nodeText) { _, newValue in
                            node.text = newValue
                        }
                    
                    // 新規バッジ
                    Text("NEW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // 追加ボタン
                Button(action: onAddChild) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(6)
                }
                
                // 削除ボタン（新規のみ）
                if !isExistingNode {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(6)
                    }
                }
            }
            
            // 理由入力
            HStack(spacing: 0) {
                ForEach(0..<level, id: \.self) { _ in
                    Color.clear.frame(width: 24)
                }
                
                HStack {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    TextField("理由（任意）", text: $reasonText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .onAppear { reasonText = connection.reason }
                        .onChange(of: reasonText) { _, newValue in
                            connection.reason = newValue
                        }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ビジュアルモード（編集用）
struct EditVisualModeView: View {
    let centerNodeText: String
    @Binding var nodes: [EditableNode]
    @Binding var connections: [EditableConnection]
    let existingNodeIds: Set<UUID>
    @Binding var selectedNodeId: UUID?
    @Binding var selectedConnectionId: UUID?
    var onShowReason: (String) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .onTapGesture {
                        selectedNodeId = nil
                        selectedConnectionId = nil
                    }
                
                // コネクション
                ForEach(connections) { connection in
                    EditModeConnectionLine(
                        connection: connection,
                        nodes: nodes,
                        existingNodeIds: existingNodeIds,
                        isSelected: selectedConnectionId == connection.id,
                        onSelect: {
                            selectedConnectionId = connection.id
                            selectedNodeId = nil
                        },
                        onShowReason: onShowReason
                    )
                }
                
                // ノード
                ForEach($nodes) { $node in
                    EditModeNodeView(
                        node: $node,
                        centerNodeText: centerNodeText,
                        isExisting: existingNodeIds.contains(node.id),
                        isSelected: selectedNodeId == node.id,
                        canDrag: selectedNodeId == node.id && !existingNodeIds.contains(node.id),
                        onSelect: {
                            selectedNodeId = node.id
                            selectedConnectionId = nil
                        }
                    )
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, 0.3), 3.0)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if selectedNodeId == nil || existingNodeIds.contains(selectedNodeId!) {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
        }
        .clipped()
    }
}

// MARK: - 編集モード用ノードView
struct EditModeNodeView: View {
    @Binding var node: EditableNode
    let centerNodeText: String
    let isExisting: Bool
    let isSelected: Bool
    let canDrag: Bool
    let onSelect: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var displayText: String {
        node.isCenter ? centerNodeText : node.text
    }
    
    var nodeSize: CGFloat {
        node.isCenter ? 100 : 80
    }
    
    var body: some View {
        ZStack {
            // 選択枠
            if isSelected {
                Circle()
                    .stroke(Color.pink, lineWidth: 4)
                    .frame(width: nodeSize + 8, height: nodeSize + 8)
            }
            
            // ノード本体
            Circle()
                .fill(
                    node.isCenter
                        ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            // 枠線（新規は緑、既存は紫）
            if !node.isCenter {
                Circle()
                    .stroke(
                        isExisting ? Color.purple.opacity(0.5) : Color.green,
                        lineWidth: isExisting ? 2 : 3
                    )
                    .frame(width: nodeSize, height: nodeSize)
            }
            
            // テキスト
            Text(displayText)
                .font(.system(size: node.isCenter ? 14 : 12))
                .fontWeight(node.isCenter ? .bold : .medium)
                .foregroundColor(node.isCenter ? .white : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(width: nodeSize - 16)
            
            // 新規バッジ
            if !isExisting && !node.isCenter {
                VStack {
                    HStack {
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 8))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .frame(width: nodeSize, height: nodeSize)
            }
            
            // ロックアイコン（既存ノード）
            if isExisting && !node.isCenter {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.purple.opacity(0.8))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .frame(width: nodeSize, height: nodeSize)
            }
        }
        .position(x: node.positionX + dragOffset.width, y: node.positionY + dragOffset.height)
        .onTapGesture { onSelect() }
        .gesture(
            canDrag ? DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    node.positionX += value.translation.width
                    node.positionY += value.translation.height
                    dragOffset = .zero
                } : nil
        )
    }
}

// MARK: - 編集モード用コネクションLine
struct EditModeConnectionLine: View {
    let connection: EditableConnection
    let nodes: [EditableNode]
    let existingNodeIds: Set<UUID>
    let isSelected: Bool
    let onSelect: () -> Void
    var onShowReason: (String) -> Void
    
    var isNewConnection: Bool {
        !existingNodeIds.contains(connection.toNodeId)
    }
    
    var body: some View {
        if let fromNode = nodes.first(where: { $0.id == connection.fromNodeId }),
           let toNode = nodes.first(where: { $0.id == connection.toNodeId }) {
            
            let fromPoint = CGPoint(x: fromNode.positionX, y: fromNode.positionY)
            let toPoint = CGPoint(x: toNode.positionX, y: toNode.positionY)
            
            let fromRadius: CGFloat = fromNode.isCenter ? 50 : 40
            let toRadius: CGFloat = toNode.isCenter ? 50 : 40
            
            let angle = atan2(toPoint.y - fromPoint.y, toPoint.x - fromPoint.x)
            let adjustedFromPoint = CGPoint(
                x: fromPoint.x + cos(angle) * fromRadius,
                y: fromPoint.y + sin(angle) * fromRadius
            )
            let adjustedToPoint = CGPoint(
                x: toPoint.x - cos(angle) * toRadius,
                y: toPoint.y - sin(angle) * toRadius
            )
            
            let midPoint = CGPoint(
                x: (adjustedFromPoint.x + adjustedToPoint.x) / 2,
                y: (adjustedFromPoint.y + adjustedToPoint.y) / 2
            )
            
            ZStack {
                // 線
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .stroke(
                    isSelected ? Color.pink : (isNewConnection ? Color.green : Color.purple.opacity(0.5)),
                    style: StrokeStyle(lineWidth: isSelected ? 4 : 2, lineCap: .round)
                )
                
                // 矢印
                ArrowHead(
                    at: adjustedToPoint,
                    angle: angle,
                    size: 12,
                    color: isSelected ? Color.pink : (isNewConnection ? Color.green : Color.purple.opacity(0.7))
                )
                
                // タップ領域
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .stroke(Color.clear, lineWidth: 30)
                .contentShape(
                    Path { path in
                        path.move(to: adjustedFromPoint)
                        path.addLine(to: adjustedToPoint)
                    }
                    .strokedPath(StrokeStyle(lineWidth: 30))
                )
                .onTapGesture { onSelect() }
                
                // 理由ボタン
                if !connection.reason.isEmpty {
                    Button(action: { onShowReason(connection.reason) }) {
                        ZStack {
                            Circle()
                                .fill(isNewConnection ? Color.green : Color.purple)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                    .position(midPoint)
                }
            }
        }
    }
}
