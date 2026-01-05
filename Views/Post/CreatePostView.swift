// Views/Post/CreatePostView.swift

import SwiftUI
import Supabase

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var centerNodeText = ""
    @State private var nodes: [StyledNode] = []
    @State private var connections: [StyledConnection] = []
    @State private var selectedNodeId: UUID? = nil
    @State private var selectedConnectionId: UUID? = nil
    @State private var isTextMode = true
    @State private var scale: CGFloat = 1.0
    @State private var visualScale: CGFloat = 1.0
    @State private var visualOffset: CGSize = .zero
    @State private var isPosting = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showPreview = false
    @State private var showUnifyStyle = false
    
    // 編集シート
    @State private var showNodeEditor = false
    @State private var editingNodeIndex: Int? = nil
    @State private var editingConnectionIndex: Int? = nil
    
    // 履歴管理
    @State private var history: [MindMapState] = []
    @State private var historyIndex = -1
    
    // 理由ポップアップ
    @State private var popupReason = ""
    @State private var showReasonPopup = false
    
    // 確認ダイアログ
    @State private var showDeleteConfirm = false
    @State private var showPostConfirm = false
    
    private var canPost: Bool {
        !centerNodeText.trimmingCharacters(in: .whitespaces).isEmpty && nodes.count >= 2
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // モード切替
                Picker("モード", selection: $isTextMode) {
                    Text("テキスト").tag(true)
                    Text("ビジュアル").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if isTextMode {
                    TextModeView(
                        centerNodeText: $centerNodeText,
                        nodes: $nodes,
                        connections: $connections,
                        scale: scale,
                        onSaveHistory: saveHistory
                    )
                } else {
                    ZStack {
                        VisualModeView(
                            centerNodeText: centerNodeText,
                            nodes: $nodes,
                            connections: $connections,
                            selectedNodeId: $selectedNodeId,
                            selectedConnectionId: $selectedConnectionId,
                            scale: $visualScale,
                            offset: $visualOffset,
                            onShowReason: { reason in
                                popupReason = reason
                                showReasonPopup = true
                            },
                            onSaveHistory: saveHistory
                        )
                        
                        // フローティング編集ボタン
                        if selectedNodeId != nil || selectedConnectionId != nil {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    
                                    // 編集ボタン
                                    Button(action: openSelectedEditor) {
                                        Image(systemName: "pencil")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .frame(width: 56, height: 56)
                                            .background(Color.purple)
                                            .clipShape(Circle())
                                            .shadow(radius: 4)
                                    }
                                    
                                    // 削除ボタン（ノード選択時のみ、中心ノード以外）
                                    if let nodeId = selectedNodeId,
                                       let node = nodes.first(where: { $0.id == nodeId }),
                                       !node.isCenter {
                                        Button(action: { deleteSelectedNode() }) {
                                            Image(systemName: "trash")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .frame(width: 56, height: 56)
                                                .background(Color.red)
                                                .clipShape(Circle())
                                                .shadow(radius: 4)
                                        }
                                    }
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 100)
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: { showPreview = true }) {
                            Image(systemName: "eye")
                                .font(.system(size: 16))
                        }
                        
                        Button(action: { showUnifyStyle = true }) {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 16))
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !isTextMode {
                            Button(action: resetZoom) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14))
                            }
                            
                            Button(action: addNodeToCenter) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16))
                            }
                        }
                        
                        Button(action: undo) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14))
                        }
                        .disabled(historyIndex <= 0)
                        
                        // メニューボタン
                        Menu {
                            Button(action: saveDraft) {
                                Label("下書き保存", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: { showPostConfirm = true }) {
                                Label("投稿", systemImage: "paperplane")
                            }
                            .disabled(!canPost)
                            
                            Divider()
                            
                            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                                Label("この投稿を削除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showPreview) {
                PostPreviewView(
                    centerNodeText: centerNodeText,
                    nodes: nodes,
                    connections: connections
                )
            }
            .sheet(isPresented: $showUnifyStyle) {
                UnifyStyleView(
                    nodes: $nodes,
                    connections: $connections,
                    centerNodeText: centerNodeText
                )
            }
            .sheet(isPresented: $showNodeEditor) {
                if let nodeIndex = editingNodeIndex {
                    NodeStyleEditor(
                        node: $nodes[nodeIndex],
                        centerNodeText: $centerNodeText,
                        connection: editingConnectionIndex != nil ? $connections[editingConnectionIndex!] : nil
                    )
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .alert("この投稿を削除", isPresented: $showDeleteConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("この操作は戻れません。削除しますか？")
            }
            .alert("投稿確認", isPresented: $showPostConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("投稿") {
                    postToSupabase()
                }
            } message: {
                Text("投稿を確定してよろしいですか？")
            }
            .overlay {
                if showReasonPopup {
                    CreatePostReasonPopup(
                        reason: popupReason,
                        onDismiss: { showReasonPopup = false }
                    )
                }
            }
            .onAppear {
                initializeIfNeeded()
            }
        }
    }
    
    // MARK: - Methods
    
    private func initializeIfNeeded() {
        if nodes.isEmpty {
            let centerNode = StyledNode(
                id: UUID(),
                text: "",
                positionX: UIScreen.main.bounds.width / 2,
                positionY: 300,
                isCenter: true,
                parentId: nil,
                style: .defaultCenter,
                detail: ""
            )
            nodes.append(centerNode)
            saveHistory()
        }
    }
    
    private func openSelectedEditor() {
        if let nodeId = selectedNodeId,
           let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            editingNodeIndex = index
            
            if let connIndex = connections.firstIndex(where: { $0.toNodeId == nodeId }) {
                editingConnectionIndex = connIndex
            } else {
                editingConnectionIndex = nil
            }
            
            showNodeEditor = true
        } else if let connectionId = selectedConnectionId,
                  let connIndex = connections.firstIndex(where: { $0.id == connectionId }) {
            let toNodeId = connections[connIndex].toNodeId
            if let nodeIndex = nodes.firstIndex(where: { $0.id == toNodeId }) {
                editingNodeIndex = nodeIndex
                editingConnectionIndex = connIndex
                showNodeEditor = true
            }
        }
    }
    
    private func deleteSelectedNode() {
        guard let nodeId = selectedNodeId else { return }
        saveHistory()
        
        var nodesToDelete: Set<UUID> = [nodeId]
        var changed = true
        
        while changed {
            changed = false
            for conn in connections {
                if nodesToDelete.contains(conn.fromNodeId) && !nodesToDelete.contains(conn.toNodeId) {
                    nodesToDelete.insert(conn.toNodeId)
                    changed = true
                }
            }
        }
        
        nodes.removeAll { nodesToDelete.contains($0.id) }
        connections.removeAll { nodesToDelete.contains($0.fromNodeId) || nodesToDelete.contains($0.toNodeId) }
        selectedNodeId = nil
        
        HapticManager.shared.lightImpact()
    }
    
    private func addNodeToCenter() {
        saveHistory()
        
        guard let centerNode = nodes.first(where: { $0.isCenter }) else { return }
        
        let existingChildren = connections.filter { $0.fromNodeId == centerNode.id }.count
        let angles: [Double] = [-Double.pi / 2, -Double.pi / 6, Double.pi / 6, Double.pi * 5 / 6, -Double.pi * 5 / 6]
        let angleIndex = existingChildren % angles.count
        let ring = existingChildren / angles.count
        let angle = angles[angleIndex]
        
        let baseDistance: Double = 160
        let distance = baseDistance + Double(ring) * 100
        let newX = centerNode.positionX + cos(angle) * distance
        let newY = centerNode.positionY + sin(angle) * distance
        
        let newNode = StyledNode(
            id: UUID(),
            text: "",
            positionX: newX,
            positionY: newY,
            isCenter: false,
            parentId: centerNode.id,
            style: .defaultChild,
            detail: ""
        )
        
        let newConnection = StyledConnection(
            id: UUID(),
            fromNodeId: centerNode.id,
            toNodeId: newNode.id,
            reason: "",
            style: .defaultStyle
        )
        
        nodes.append(newNode)
        connections.append(newConnection)
        selectedNodeId = newNode.id
        
        HapticManager.shared.lightImpact()
    }
    
    private func resetZoom() {
        withAnimation(.spring(response: 0.3)) {
            visualScale = 1.0
            visualOffset = .zero
        }
    }
    
    private func saveHistory() {
        let state = MindMapState(nodes: nodes, connections: connections, centerNodeText: centerNodeText)
        
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        
        history.append(state)
        
        if history.count > 20 {
            history.removeFirst()
        }
        
        historyIndex = history.count - 1
    }
    
    private func undo() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        let state = history[historyIndex]
        nodes = state.nodes
        connections = state.connections
        centerNodeText = state.centerNodeText
        
        HapticManager.shared.lightImpact()
    }
    
    private func saveDraft() {
        let draftNodes = nodes.map { node in
            DraftNode(
                id: node.id,
                text: node.isCenter ? centerNodeText : node.text,
                positionX: node.positionX,
                positionY: node.positionY,
                isCenter: node.isCenter
            )
        }
        
        let draftConnections = connections.map { conn in
            DraftConnection(
                id: conn.id,
                fromNodeId: conn.fromNodeId,
                toNodeId: conn.toNodeId,
                reason: conn.reason
            )
        }
        
        let draft = DraftPost(
            id: UUID(),
            centerNodeText: centerNodeText,
            nodes: draftNodes,
            connections: draftConnections,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        DraftManager.shared.saveDraft(draft)
        HapticManager.shared.success()
        dismiss()
    }
    
    private func postToSupabase() {
        isPosting = true
        
        Task {
            do {
                guard let userId = authService.currentUser?.id else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーが見つかりません"])
                }
                
                let nodeInputs = nodes.map { node in
                    let styleJSON = NodeStyleJSON(from: node.style)
                    let styleString = (try? JSONEncoder().encode(styleJSON)).flatMap { String(data: $0, encoding: .utf8) }
                    
                    return NodeInput(
                        localId: node.id.uuidString,
                        text: node.isCenter ? centerNodeText : node.text,
                        positionX: node.positionX,
                        positionY: node.positionY,
                        isCenter: node.isCenter,
                        note: node.detail.isEmpty ? nil : node.detail,
                        style: styleString
                    )
                }
                
                let connectionInputs = connections.map { conn in
                    let styleJSON = ConnectionStyleJSON(from: conn.style)
                    let styleString = (try? JSONEncoder().encode(styleJSON)).flatMap { String(data: $0, encoding: .utf8) }
                    
                    return ConnectionInput(
                        fromLocalId: conn.fromNodeId.uuidString,
                        toLocalId: conn.toNodeId.uuidString,
                        reason: conn.reason.isEmpty ? nil : conn.reason,
                        style: styleString
                    )
                }
                
                _ = try await PostService.shared.createPost(
                    userId: userId,
                    centerNodeText: centerNodeText,
                    nodes: nodeInputs,
                    connections: connectionInputs
                )
                
                await MainActor.run {
                    isPosting = false
                    HapticManager.shared.success()
                    NotificationCenter.default.post(name: .postCreated, object: nil)
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

// MARK: - 理由ポップアップ（CreatePost専用）
struct CreatePostReasonPopup: View {
    let reason: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.purple)
                    Text("つながりの理由")
                        .font(.headline)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(reason)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - テキストモードView
struct TextModeView: View {
    @Binding var centerNodeText: String
    @Binding var nodes: [StyledNode]
    @Binding var connections: [StyledConnection]
    let scale: CGFloat
    var onSaveHistory: () -> Void
    
    @State private var expandedNodes: Set<UUID> = []
    @State private var selectedNodeId: UUID? = nil
    @State private var showingReasonForNodeId: UUID? = nil
    @State private var isFullyExpanded = true
    
    @State private var showNodeEditor = false
    @State private var editingNodeIndex: Int? = nil
    @State private var editingConnectionIndex: Int? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            if isFullyExpanded {
                                expandedNodes.removeAll()
                            } else {
                                expandedNodes = Set(nodes.map { $0.id })
                            }
                            isFullyExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isFullyExpanded ? "chevron.up.circle" : "chevron.down.circle")
                            Text(isFullyExpanded ? "折りたたむ" : "すべて展開")
                                .font(.caption)
                        }
                        .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                TreeRootRow(
                    text: $centerNodeText,
                    isExpanded: true,
                    hasChildren: hasChildren(nodeId: nodes.first(where: { $0.isCenter })?.id),
                    hasDetail: nodes.first(where: { $0.isCenter })?.hasDetail ?? false,
                    scale: scale,
                    nodeIndex: 1,
                    onToggleExpand: {},
                    onAddChild: { addChildToCenter() },
                    onLongPress: { openCenterNodeEditor() }
                )
                
                if let centerNode = nodes.first(where: { $0.isCenter }) {
                    TreeChildNodesView(
                        parentId: centerNode.id,
                        nodes: $nodes,
                        connections: $connections,
                        expandedNodes: $expandedNodes,
                        selectedNodeId: $selectedNodeId,
                        showingReasonForNodeId: $showingReasonForNodeId,
                        scale: scale,
                        level: 1,
                        onAddChild: addChild,
                        onDeleteNode: deleteNode,
                        hasChildrenCheck: hasChildren,
                        getNodeIndex: getNodeIndex,
                        onLongPressNode: openNodeEditor,
                        onSaveHistory: onSaveHistory
                    )
                }
                
                Color.clear
                    .frame(height: 300)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNodeId = nil
                        showingReasonForNodeId = nil
                    }
            }
            .padding(.bottom, 100)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedNodeId = nil
            showingReasonForNodeId = nil
        }
        .sheet(isPresented: $showNodeEditor) {
            if let nodeIndex = editingNodeIndex {
                NodeStyleEditor(
                    node: $nodes[nodeIndex],
                    centerNodeText: $centerNodeText,
                    connection: editingConnectionIndex != nil ? $connections[editingConnectionIndex!] : nil
                )
            }
        }
    }
    
    private func openCenterNodeEditor() {
        if let index = nodes.firstIndex(where: { $0.isCenter }) {
            editingNodeIndex = index
            editingConnectionIndex = nil
            showNodeEditor = true
        }
    }
    
    private func openNodeEditor(nodeId: UUID) {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            editingNodeIndex = index
            
            if let connIndex = connections.firstIndex(where: { $0.toNodeId == nodeId }) {
                editingConnectionIndex = connIndex
            } else {
                editingConnectionIndex = nil
            }
            
            showNodeEditor = true
        }
    }
    
    private func getNodeIndex(nodeId: UUID) -> Int {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            return index + 1
        }
        return 0
    }
    
    private func hasChildren(nodeId: UUID?) -> Bool {
        guard let nodeId = nodeId else { return false }
        return connections.contains { $0.fromNodeId == nodeId }
    }
    
    private func addChildToCenter() {
        onSaveHistory()
        
        var centerNode = nodes.first(where: { $0.isCenter })
        
        if centerNode == nil {
            let newCenterNode = StyledNode(
                id: UUID(),
                text: centerNodeText.isEmpty ? "テーマ" : centerNodeText,
                positionX: UIScreen.main.bounds.width / 2,
                positionY: 300,
                isCenter: true,
                parentId: nil,
                style: .defaultCenter,
                detail: ""
            )
            nodes.insert(newCenterNode, at: 0)
            centerNode = newCenterNode
        }
        
        guard let center = centerNode else { return }
        
        let existingChildren = connections.filter { $0.fromNodeId == center.id }.count
        let angles: [Double] = [-Double.pi / 2, -Double.pi / 6, Double.pi / 6, Double.pi * 5 / 6, -Double.pi * 5 / 6]
        let angleIndex = existingChildren % angles.count
        let ring = existingChildren / angles.count
        let angle = angles[angleIndex]
        
        let baseDistance: Double = 160
        let distance = baseDistance + Double(ring) * 100
        let newX = center.positionX + cos(angle) * distance
        let newY = center.positionY + sin(angle) * distance
        
        let newNode = StyledNode(
            id: UUID(),
            text: "",
            positionX: newX,
            positionY: newY,
            isCenter: false,
            parentId: center.id,
            style: .defaultChild,
            detail: ""
        )
        
        let newConnection = StyledConnection(
            id: UUID(),
            fromNodeId: center.id,
            toNodeId: newNode.id,
            reason: "",
            style: .defaultStyle
        )
        
        nodes.append(newNode)
        connections.append(newConnection)
        expandedNodes.insert(center.id)
    }
    
    private func addChild(parentId: UUID) {
        onSaveHistory()
        
        guard let parentNode = nodes.first(where: { $0.id == parentId }) else { return }
        
        let existingChildren = connections.filter { $0.fromNodeId == parentId }.count
        let spreadAngle: Double = .pi / 4
        let baseAngle: Double
        
        if let parentConnection = connections.first(where: { $0.toNodeId == parentId }),
           let grandParent = nodes.first(where: { $0.id == parentConnection.fromNodeId }) {
            baseAngle = atan2(parentNode.positionY - grandParent.positionY, parentNode.positionX - grandParent.positionX)
        } else {
            baseAngle = 0
        }
        
        let angleOffset = Double(existingChildren) * spreadAngle - Double(existingChildren) * spreadAngle / 2
        let angle = baseAngle + angleOffset
        let distance: Double = 120
        
        let newX = parentNode.positionX + cos(angle) * distance
        let newY = parentNode.positionY + sin(angle) * distance
        
        let newNode = StyledNode(
            id: UUID(),
            text: "",
            positionX: newX,
            positionY: newY,
            isCenter: false,
            parentId: parentId,
            style: .defaultChild,
            detail: ""
        )
        
        let newConnection = StyledConnection(
            id: UUID(),
            fromNodeId: parentId,
            toNodeId: newNode.id,
            reason: "",
            style: .defaultStyle
        )
        
        nodes.append(newNode)
        connections.append(newConnection)
        expandedNodes.insert(parentId)
    }
    
    private func deleteNode(nodeId: UUID) {
        onSaveHistory()
        
        var nodesToDelete: Set<UUID> = [nodeId]
        var changed = true
        
        while changed {
            changed = false
            for conn in connections {
                if nodesToDelete.contains(conn.fromNodeId) && !nodesToDelete.contains(conn.toNodeId) {
                    nodesToDelete.insert(conn.toNodeId)
                    changed = true
                }
            }
        }
        
        nodes.removeAll { nodesToDelete.contains($0.id) }
        connections.removeAll { nodesToDelete.contains($0.fromNodeId) || nodesToDelete.contains($0.toNodeId) }
    }
}

// MARK: - ルート行
struct TreeRootRow: View {
    @Binding var text: String
    let isExpanded: Bool
    let hasChildren: Bool
    let hasDetail: Bool
    let scale: CGFloat
    let nodeIndex: Int
    let onToggleExpand: () -> Void
    let onAddChild: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        HStack(spacing: 4 * scale) {
            Button(action: onToggleExpand) {
                if hasChildren {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12 * scale, weight: .bold))
                        .foregroundColor(.secondary)
                } else {
                    Color.clear
                }
            }
            .frame(width: 16 * scale)
            .disabled(!hasChildren)
            
            ZStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18 * scale))
                    .foregroundColor(hasDetail ? .orange : .purple)
                
                Text("\(nodeIndex)")
                    .font(.system(size: 8 * scale, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: 1)
            }
            
            TextField("テーマを入力", text: $text)
                .font(.system(size: 14 * scale, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onAddChild) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18 * scale))
                    .foregroundColor(.purple.opacity(0.6))
            }
            .padding(.trailing, 4)
        }
        .padding(.vertical, 8 * scale)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.1))
        )
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            HapticManager.shared.lightImpact()
            onLongPress()
        }
    }
}

// MARK: - 子ノード表示View
struct TreeChildNodesView: View {
    let parentId: UUID
    @Binding var nodes: [StyledNode]
    @Binding var connections: [StyledConnection]
    @Binding var expandedNodes: Set<UUID>
    @Binding var selectedNodeId: UUID?
    @Binding var showingReasonForNodeId: UUID?
    let scale: CGFloat
    let level: Int
    let onAddChild: (UUID) -> Void
    let onDeleteNode: (UUID) -> Void
    let hasChildrenCheck: (UUID?) -> Bool
    let getNodeIndex: (UUID) -> Int
    let onLongPressNode: (UUID) -> Void
    var onSaveHistory: () -> Void
    
    var childConnections: [StyledConnection] {
        connections.filter { $0.fromNodeId == parentId }
    }
    
    var body: some View {
        ForEach(childConnections) { connection in
            if let nodeIndex = nodes.firstIndex(where: { $0.id == connection.toNodeId }) {
                let node = nodes[nodeIndex]
                let hasChildren = hasChildrenCheck(node.id)
                let isExpanded = expandedNodes.contains(node.id)
                let isSelected = selectedNodeId == node.id
                let isShowingReason = showingReasonForNodeId == node.id
                
                VStack(alignment: .leading, spacing: 0) {
                    TreeNodeRow(
                        node: $nodes[nodeIndex],
                        connection: connectionBinding(for: connection.id),
                        isSelected: isSelected,
                        hasChildren: hasChildren,
                        isExpanded: isExpanded,
                        isShowingReason: isShowingReason,
                        scale: scale,
                        level: level,
                        nodeIndex: getNodeIndex(node.id),
                        onSelect: { selectedNodeId = node.id },
                        onToggleExpand: {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedNodes.contains(node.id) {
                                    expandedNodes.remove(node.id)
                                } else {
                                    expandedNodes.insert(node.id)
                                }
                            }
                        },
                        onToggleReason: {
                            withAnimation(.spring(response: 0.3)) {
                                if showingReasonForNodeId == node.id {
                                    showingReasonForNodeId = nil
                                } else {
                                    showingReasonForNodeId = node.id
                                }
                            }
                        },
                        onAddChild: { onAddChild(node.id) },
                        onDelete: { onDeleteNode(node.id) },
                        onLongPress: { onLongPressNode(node.id) },
                        onSaveHistory: onSaveHistory
                    )
                    
                    if isShowingReason {
                        ConnectionReasonInput(
                            connection: connectionBinding(for: connection.id),
                            scale: scale,
                            level: level
                        )
                    }
                }
                
                if isExpanded {
                    TreeChildNodesView(
                        parentId: node.id,
                        nodes: $nodes,
                        connections: $connections,
                        expandedNodes: $expandedNodes,
                        selectedNodeId: $selectedNodeId,
                        showingReasonForNodeId: $showingReasonForNodeId,
                        scale: scale,
                        level: level + 1,
                        onAddChild: onAddChild,
                        onDeleteNode: onDeleteNode,
                        hasChildrenCheck: hasChildrenCheck,
                        getNodeIndex: getNodeIndex,
                        onLongPressNode: onLongPressNode,
                        onSaveHistory: onSaveHistory
                    )
                }
            }
        }
    }
    
    private func connectionBinding(for connectionId: UUID) -> Binding<StyledConnection> {
        Binding(
            get: {
                connections.first(where: { $0.id == connectionId }) ?? StyledConnection(
                    id: connectionId,
                    fromNodeId: UUID(),
                    toNodeId: UUID(),
                    reason: "",
                    style: .defaultStyle
                )
            },
            set: { newValue in
                if let idx = connections.firstIndex(where: { $0.id == connectionId }) {
                    connections[idx] = newValue
                }
            }
        )
    }
}

// MARK: - ノード行
struct TreeNodeRow: View {
    @Binding var node: StyledNode
    @Binding var connection: StyledConnection
    let isSelected: Bool
    let hasChildren: Bool
    let isExpanded: Bool
    let isShowingReason: Bool
    let scale: CGFloat
    let level: Int
    let nodeIndex: Int
    let onSelect: () -> Void
    let onToggleExpand: () -> Void
    let onToggleReason: () -> Void
    let onAddChild: () -> Void
    let onDelete: () -> Void
    let onLongPress: () -> Void
    var onSaveHistory: () -> Void
    
    var hasReason: Bool {
        !connection.reason.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var linkIconColor: Color {
        if isShowingReason {
            return .pink
        } else if hasReason {
            return .orange
        } else {
            return .purple.opacity(0.4)
        }
    }
    
    // アイコンの色（詳細ありならオレンジ、なければ紫）
    var iconColor: Color {
        if isSelected {
            return .blue
        } else if node.hasDetail {
            return .orange
        } else if hasChildren {
            return .orange
        } else {
            return .purple
        }
    }
    
    var body: some View {
        HStack(spacing: 4 * scale) {
            ForEach(0..<level, id: \.self) { i in
                if i == level - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12 * scale, weight: .bold))
                        .foregroundColor(.purple.opacity(0.7))
                        .frame(width: 16 * scale)
                } else {
                    Rectangle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 2)
                        .padding(.horizontal, 7 * scale)
                }
            }
            
            Button(action: onToggleExpand) {
                if hasChildren {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12 * scale, weight: .bold))
                        .foregroundColor(.secondary)
                } else {
                    Color.clear
                }
            }
            .frame(width: 16 * scale)
            .disabled(!hasChildren)
            
            ZStack {
                Image(systemName: hasChildren ? "folder.fill" : "doc.fill")
                    .font(.system(size: 18 * scale))
                    .foregroundColor(node.hasDetail ? .orange : (hasChildren ? .orange : .purple))
                
                Text("\(nodeIndex)")
                    .font(.system(size: 8 * scale, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: 1)
            }
            
            TextField("ノード名を入力", text: $node.text, onEditingChanged: { isEditing in
                if !isEditing {
                    onSaveHistory()
                }
            })
            .font(.system(size: 14 * scale))
            .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 6 * scale) {
                Button(action: onToggleReason) {
                    Image(systemName: hasReason ? "link.circle.fill" : "link.circle")
                        .font(.system(size: 18 * scale))
                        .foregroundColor(linkIconColor)
                }
                
                Button(action: onAddChild) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18 * scale))
                        .foregroundColor(.purple.opacity(0.6))
                }
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 18 * scale))
                        .foregroundColor(.red.opacity(0.6))
                }
            }
            .padding(.trailing, 4)
        }
        .padding(.vertical, 6 * scale)
        .padding(.horizontal, 8)
        .padding(.leading, CGFloat(level) * 8 * scale)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onLongPressGesture(minimumDuration: 0.5) {
            HapticManager.shared.lightImpact()
            onLongPress()
        }
    }
}

// MARK: - 接続理由入力
struct ConnectionReasonInput: View {
    @Binding var connection: StyledConnection
    let scale: CGFloat
    let level: Int
    
    var body: some View {
        HStack(spacing: 4 * scale) {
            ForEach(0..<level, id: \.self) { _ in
                Rectangle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 2)
                    .padding(.horizontal, 7 * scale)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 12))
                    .foregroundColor(.purple)
                
                TextField("なぜつながる？", text: $connection.reason)
                    .font(.system(size: 12 * scale))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.purple.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.trailing, 60)
        }
        .padding(.leading, CGFloat(level) * 8 * scale + 20)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - ビジュアルモードView
struct VisualModeView: View {
    let centerNodeText: String
    @Binding var nodes: [StyledNode]
    @Binding var connections: [StyledConnection]
    @Binding var selectedNodeId: UUID?
    @Binding var selectedConnectionId: UUID?
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    var onShowReason: (String) -> Void
    var onSaveHistory: () -> Void
    
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNodeId = nil
                        selectedConnectionId = nil
                    }
                
                ZStack {
                    ForEach($connections) { $connection in
                        StyledConnectionLine(
                            connection: $connection,
                            nodes: nodes,
                            centerNodeText: centerNodeText,
                            isSelected: selectedConnectionId == connection.id,
                            onSelect: {
                                selectedConnectionId = connection.id
                                selectedNodeId = nil
                            }
                        )
                    }
                    
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                        StyledNodeView(
                            node: $nodes[index],
                            centerNodeText: centerNodeText,
                            isSelected: selectedNodeId == node.id,
                            canDrag: selectedNodeId == node.id,
                            onSelect: {
                                selectedNodeId = node.id
                                selectedConnectionId = nil
                            },
                            nodeIndex: index + 1,
                            onDragStart: onSaveHistory
                        )
                    }
                }
                .scaleEffect(scale * gestureScale)
                .offset(offset)
            }
            .gesture(
                MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        scale = min(max(scale * value, 0.3), 3.0)
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if selectedNodeId == nil && selectedConnectionId == nil {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { value in
                        if selectedNodeId == nil && selectedConnectionId == nil {
                            lastOffset = offset
                        }
                    }
            )
        }
        .clipped()
    }
}

// MARK: - スタイル付きノードView
struct StyledNodeView: View {
    @Binding var node: StyledNode
    let centerNodeText: String
    let isSelected: Bool
    let canDrag: Bool
    let onSelect: () -> Void
    var nodeIndex: Int = 0
    var onDragStart: (() -> Void)? = nil
    
    @GestureState private var dragOffset: CGSize = .zero
    
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
                    .stroke(Color.blue, lineWidth: 4)
                    .frame(width: nodeSize + 8, height: nodeSize + 8)
            }
            
            Circle()
                .fill(node.style.fillColor.color)
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            Circle()
                .stroke(node.style.borderColor.color, lineWidth: 2)
                .frame(width: nodeSize, height: nodeSize)
            
            Text(displayText)
                .font(.system(size: node.isCenter ? 14 : 12))
                .fontWeight(node.isCenter ? .bold : .medium)
                .foregroundColor(node.style.textColor.color)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(width: nodeSize - 16)
            
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 24, height: 24)
                
                Text("\(nodeIndex)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(x: -(nodeSize / 2) + 8, y: -(nodeSize / 2) + 8)
            
            // 詳細ありバッジ
            if node.hasDetail {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
                .offset(x: (nodeSize / 2) - 8, y: -(nodeSize / 2) + 8)
            }
        }
        .position(
            x: node.positionX + dragOffset.width,
            y: node.positionY + dragOffset.height
        )
        .onTapGesture { onSelect() }
        .highPriorityGesture(
            canDrag ?
            DragGesture(minimumDistance: 1)
                .updating($dragOffset) { value, state, _ in
                    if state == .zero {
                        DispatchQueue.main.async { onDragStart?() }
                    }
                    state = value.translation
                }
                .onEnded { value in
                    node.positionX += value.translation.width
                    node.positionY += value.translation.height
                }
            : nil
        )
    }
}

// MARK: - スタイル付き接続線
struct StyledConnectionLine: View {
    @Binding var connection: StyledConnection
    let nodes: [StyledNode]
    let centerNodeText: String
    let isSelected: Bool
    let onSelect: () -> Void
    
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
                    connection.style.lineColor.color,
                    style: StrokeStyle(lineWidth: connection.style.lineWidth, lineCap: .round)
                )
                
                if isSelected {
                    Path { path in
                        path.move(to: adjustedFromPoint)
                        path.addLine(to: adjustedToPoint)
                    }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: connection.style.lineWidth + 4, lineCap: .round))
                    .opacity(0.3)
                }
                
                if !connection.reason.isEmpty {
                    ZStack {
                        Circle()
                            .fill(connection.style.lineColor.color)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .position(midPoint)
                }
            }
            .contentShape(
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .strokedPath(StrokeStyle(lineWidth: 20))
            )
            .onTapGesture { onSelect() }
        }
    }
}
