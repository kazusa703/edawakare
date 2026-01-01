// Views/Post/CreatePostView.swift

import SwiftUI
import Supabase

// MARK: - CreatePostView
struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var showCenterNodeInput = true
    @State private var centerNodeText = ""
    @State private var editMode: EditMode = .text
    @State private var nodes: [EditableNode] = []
    @State private var connections: [EditableConnection] = []
    @State private var selectedNodeId: UUID?
    @State private var selectedConnectionId: UUID?
    @State private var showEditSheet = false
    @State private var editingText = ""
    @State private var editingType: EditingType = .node
    @State private var showReasonPopup = false
    @State private var popupReason = ""
    @State private var isPosting = false
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
                    if showCenterNodeInput {
                        CenterNodeInputView(
                            centerNodeText: $centerNodeText,
                            onConfirm: {
                                createCenterNode()
                                showCenterNodeInput = false
                            }
                        )
                    } else {
                        Picker("編集モード", selection: $editMode) {
                            ForEach(EditMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        if editMode == .visual {
                            VisualToolbar(
                                hasSelection: selectedNodeId != nil || selectedConnectionId != nil,
                                onAdd: addChildNode,
                                onEdit: startEditing,
                                onDelete: deleteSelected
                            )
                        }
                        
                        if editMode == .text {
                            TextModeView(
                                centerNodeText: centerNodeText,
                                nodes: $nodes,
                                connections: $connections,
                                onEditCenterNode: {
                                    editingType = .node
                                    editingText = centerNodeText
                                    showEditSheet = true
                                }
                            )
                        } else {
                            VisualModeView(
                                centerNodeText: centerNodeText,
                                nodes: $nodes,
                                connections: $connections,
                                selectedNodeId: $selectedNodeId,
                                selectedConnectionId: $selectedConnectionId,
                                onShowReason: { reason in
                                    popupReason = reason
                                    showReasonPopup = true
                                }
                            )
                        }
                    }
                }
                
                if showReasonPopup {
                    ReasonPopupView(
                        reason: popupReason,
                        onDismiss: { showReasonPopup = false }
                    )
                }
                
                if isPosting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("投稿中...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
            .navigationTitle("新規投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isPosting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showCenterNodeInput {
                        Button("投稿") { postToSupabase() }
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                            .disabled(isPosting || !canPost)
                    }
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
        }
    }
    
    // 投稿可能かチェック（中心ノード以外に1つ以上ノードがある）
    private var canPost: Bool {
        nodes.count >= 2
    }
    
    private func createCenterNode() {
        let centerNode = EditableNode(
            id: UUID(),
            text: centerNodeText,
            positionX: UIScreen.main.bounds.width / 2,
            positionY: 300,
            isCenter: true,
            parentId: nil
        )
        nodes.append(centerNode)
    }
    
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
    
    private func startEditing() {
        if let nodeId = selectedNodeId {
            if let node = nodes.first(where: { $0.id == nodeId }) {
                if node.isCenter {
                    editingText = centerNodeText
                } else {
                    editingText = node.text
                }
                editingType = .node
                showEditSheet = true
            }
        } else if let connectionId = selectedConnectionId {
            if let connection = connections.first(where: { $0.id == connectionId }) {
                editingText = connection.reason
                editingType = .connection
                showEditSheet = true
            }
        }
    }
    
    private func saveEdit() {
        if editingType == .node {
            if let nodeId = selectedNodeId {
                if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
                    if nodes[index].isCenter {
                        centerNodeText = editingText
                    }
                    nodes[index].text = editingText
                }
            }
        } else {
            if let connectionId = selectedConnectionId {
                if let index = connections.firstIndex(where: { $0.id == connectionId }) {
                    connections[index].reason = editingText
                }
            }
        }
        showEditSheet = false
    }
    
    private func deleteSelected() {
        if let nodeId = selectedNodeId {
            if let node = nodes.first(where: { $0.id == nodeId }), node.isCenter {
                return
            }
            deleteNodeAndDescendants(nodeId: nodeId)
            selectedNodeId = nil
        } else if let connectionId = selectedConnectionId {
            if let connection = connections.first(where: { $0.id == connectionId }) {
                deleteNodeAndDescendants(nodeId: connection.toNodeId)
            }
            selectedConnectionId = nil
        }
    }
    
    private func deleteNodeAndDescendants(nodeId: UUID) {
        let childConnections = connections.filter { $0.fromNodeId == nodeId }
        for conn in childConnections {
            deleteNodeAndDescendants(nodeId: conn.toNodeId)
        }
        connections.removeAll { $0.toNodeId == nodeId || $0.fromNodeId == nodeId }
        nodes.removeAll { $0.id == nodeId }
    }
    
    // MARK: - Supabaseに投稿
    private func postToSupabase() {
        isPosting = true
        
        Task {
            do {
                // ★ 直接セッションからユーザーIDを取得
                let session = try await SupabaseClient.shared.client.auth.session
                let userId = session.user.id
                
                // ノードをNodeInput形式に変換
                let nodeInputs = nodes.map { node in
                    NodeInput(
                        localId: node.id.uuidString,
                        text: node.isCenter ? centerNodeText : node.text,
                        positionX: node.positionX,
                        positionY: node.positionY,
                        isCenter: node.isCenter
                    )
                }
                
                // コネクションをConnectionInput形式に変換
                let connectionInputs = connections.map { conn in
                    ConnectionInput(
                        fromLocalId: conn.fromNodeId.uuidString,
                        toLocalId: conn.toNodeId.uuidString,
                        reason: conn.reason.isEmpty ? nil : conn.reason
                    )
                }
                
                // PostServiceを使って投稿
                _ = try await PostService.shared.createPost(
                    userId: userId,
                    centerNodeText: centerNodeText,
                    nodes: nodeInputs,
                    connections: connectionInputs
                )
                
                await MainActor.run {
                    isPosting = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isPosting = false
                    errorMessage = "投稿に失敗しました: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - 理由ポップアップ
struct ReasonPopupView: View {
    let reason: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 16) {
                HStack {
                    Text("理由")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(reason)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - 中心ノード入力画面
struct CenterNodeInputView: View {
    @Binding var centerNodeText: String
    var onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text("中心となるテーマを入力")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("例: ストレンジャー・シングス、進撃の巨人")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            TextField("テーマを入力...", text: $centerNodeText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 32)
            
            Button(action: onConfirm) {
                Text("作成開始")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: centerNodeText.isEmpty ? [.gray] : [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(centerNodeText.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 32)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - ビジュアルモード用ツールバー
struct VisualToolbar: View {
    let hasSelection: Bool
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
            .disabled(!hasSelection)
            .foregroundColor(hasSelection ? .red : .gray)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - テキストモードView
struct TextModeView: View {
    let centerNodeText: String
    @Binding var nodes: [EditableNode]
    @Binding var connections: [EditableConnection]
    var onEditCenterNode: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CenterNodeRow(
                    text: centerNodeText,
                    onEdit: onEditCenterNode,
                    onAddChild: { addChildToCenter() }
                )
                
                let centerNode = nodes.first(where: { $0.isCenter })
                if let centerId = centerNode?.id {
                    ChildNodesTree(
                        parentId: centerId,
                        nodes: $nodes,
                        connections: $connections,
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

// MARK: - 中心ノード行
struct CenterNodeRow: View {
    let text: String
    let onEdit: () -> Void
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
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.purple)
                        .padding(8)
                }
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

// MARK: - 子ノードツリー（再帰）
struct ChildNodesTree: View {
    let parentId: UUID
    @Binding var nodes: [EditableNode]
    @Binding var connections: [EditableConnection]
    let level: Int
    
    var childConnections: [EditableConnection] {
        connections.filter { $0.fromNodeId == parentId }
    }
    
    var body: some View {
        ForEach(childConnections) { connection in
            if let nodeIndex = nodes.firstIndex(where: { $0.id == connection.toNodeId }) {
                ChildNodeRow(
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
                    onAddChild: { addChild(to: nodes[nodeIndex].id) },
                    onDelete: { deleteNode(nodes[nodeIndex].id) }
                )
                
                ChildNodesTree(
                    parentId: nodes[nodeIndex].id,
                    nodes: $nodes,
                    connections: $connections,
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
        let childConns = connections.filter { $0.fromNodeId == nodeId }
        for conn in childConns {
            deleteNode(conn.toNodeId)
        }
        connections.removeAll { $0.toNodeId == nodeId || $0.fromNodeId == nodeId }
        nodes.removeAll { $0.id == nodeId }
    }
}

// MARK: - 子ノード行（矢印付き）
struct ChildNodeRow: View {
    @Binding var node: EditableNode
    @Binding var connection: EditableConnection
    let level: Int
    let onAddChild: () -> Void
    let onDelete: () -> Void
    
    @State private var nodeText: String = ""
    @State private var reasonText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
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
                
                Circle()
                    .stroke(Color.purple, lineWidth: 2)
                    .frame(width: 14, height: 14)
                
                TextField("ノード名を入力", text: $nodeText)
                    .font(.subheadline)
                    .onAppear { nodeText = node.text }
                    .onChange(of: nodeText) { _, newValue in
                        node.text = newValue
                    }
                
                Spacer()
                
                Button(action: onAddChild) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(6)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(6)
                }
            }
            
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

// MARK: - ビジュアルモードView
struct VisualModeView: View {
    let centerNodeText: String
    @Binding var nodes: [EditableNode]
    @Binding var connections: [EditableConnection]
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
                
                ForEach(connections) { connection in
                    EditableConnectionLine(
                        connection: connection,
                        nodes: nodes,
                        isSelected: selectedConnectionId == connection.id,
                        onSelect: {
                            selectedConnectionId = connection.id
                            selectedNodeId = nil
                        },
                        onShowReason: onShowReason
                    )
                }
                
                ForEach($nodes) { $node in
                    EditableNodeView(
                        node: $node,
                        centerNodeText: centerNodeText,
                        isSelected: selectedNodeId == node.id,
                        canDrag: selectedNodeId == node.id,
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
                        if selectedNodeId == nil {
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

// MARK: - 編集可能ノードView
struct EditableNodeView: View {
    @Binding var node: EditableNode
    let centerNodeText: String
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
            if isSelected {
                Circle()
                    .stroke(Color.pink, lineWidth: 4)
                    .frame(width: nodeSize + 8, height: nodeSize + 8)
            }
            
            Circle()
                .fill(
                    node.isCenter
                        ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            if !node.isCenter {
                Circle()
                    .stroke(isSelected ? Color.pink : Color.purple.opacity(0.5), lineWidth: 2)
                    .frame(width: nodeSize, height: nodeSize)
            }
            
            Text(displayText)
                .font(.system(size: node.isCenter ? 14 : 12))
                .fontWeight(node.isCenter ? .bold : .medium)
                .foregroundColor(node.isCenter ? .white : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(width: nodeSize - 16)
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

// MARK: - 編集可能接続線View
struct EditableConnectionLine: View {
    let connection: EditableConnection
    let nodes: [EditableNode]
    let isSelected: Bool
    let onSelect: () -> Void
    var onShowReason: (String) -> Void
    
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
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .stroke(
                    isSelected ? Color.pink : Color.purple.opacity(0.5),
                    style: StrokeStyle(lineWidth: isSelected ? 4 : 2, lineCap: .round)
                )
                
                ArrowHead(
                    at: adjustedToPoint,
                    angle: angle,
                    size: 12,
                    color: isSelected ? Color.pink : Color.purple.opacity(0.7)
                )
                
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
                
                if !connection.reason.isEmpty {
                    Button(action: {
                        onShowReason(connection.reason)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.purple)
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

// MARK: - 矢印の頭
struct ArrowHead: View {
    let at: CGPoint
    let angle: CGFloat
    let size: CGFloat
    let color: Color
    
    var body: some View {
        Path { path in
            let arrowAngle: CGFloat = .pi / 6
            
            let point1 = CGPoint(
                x: at.x - size * cos(angle - arrowAngle),
                y: at.y - size * sin(angle - arrowAngle)
            )
            let point2 = CGPoint(
                x: at.x - size * cos(angle + arrowAngle),
                y: at.y - size * sin(angle + arrowAngle)
            )
            
            path.move(to: at)
            path.addLine(to: point1)
            path.move(to: at)
            path.addLine(to: point2)
        }
        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - 編集シート
struct EditTextSheet: View {
    let title: String
    @Binding var text: String
    let onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("入力...", text: $text)
                    .font(.title3)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - データモデル
struct EditableNode: Identifiable {
    let id: UUID
    var text: String
    var positionX: Double
    var positionY: Double
    var isCenter: Bool
    var parentId: UUID?
}

struct EditableConnection: Identifiable {
    let id: UUID
    let fromNodeId: UUID
    let toNodeId: UUID
    var reason: String
}
