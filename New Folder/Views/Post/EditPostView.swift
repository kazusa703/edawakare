// Views/Post/EditPostView.swift

import SwiftUI

struct EditPostView: View {
    let post: Post
    var onSave: () -> Void
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var existingNodeIds: Set<UUID> = []  // 元々あるノードのID
    @State private var nodes: [EditableNode] = []
    @State private var connections: [EditableConnection] = []
    @State private var selectedParentNode: EditableNode?
    @State private var showAddNodeSheet = false
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("新しいノードを追加できます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(nodes) { node in
                            EditNodeRow(
                                node: node,
                                isNew: !existingNodeIds.contains(node.id),
                                isSelected: selectedParentNode?.id == node.id,
                                onTap: {
                                    selectedParentNode = node
                                    showAddNodeSheet = true
                                }
                            )
                        }
                        
                        if let centerNode = nodes.first(where: { $0.isCenter }) {
                            Button(action: {
                                selectedParentNode = centerNode
                                showAddNodeSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.purple)
                                    Text("中心から新しい枝を追加")
                                        .foregroundColor(.purple)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                Divider()
                
                Button(action: saveChanges) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("保存")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding()
                .disabled(isSaving)
            }
            .navigationTitle("ノードを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddNodeSheet) {
                AddNodeSheet(
                    parentNode: selectedParentNode,
                    onAdd: { text, reason in
                        addNode(text: text, parentNode: selectedParentNode, reason: reason)
                    }
                )
            }
            .onAppear {
                loadExistingNodes()
            }
        }
    }
    
    private func loadExistingNodes() {
        // 既存のノードを読み込む
        nodes = (post.nodes ?? []).map { node in
            EditableNode(
                id: node.id,
                text: node.text,
                positionX: node.positionX,
                positionY: node.positionY,
                isCenter: node.isCenter,
                parentId: nil
            )
        }
        
        // 既存ノードIDを保存
        existingNodeIds = Set(nodes.map { $0.id })
        
        // 既存のコネクションを読み込む
        connections = (post.connections ?? []).map { conn in
            EditableConnection(
                id: conn.id,
                fromNodeId: conn.fromNodeId,
                toNodeId: conn.toNodeId,
                reason: conn.reason ?? ""
            )
        }
    }
    
    private func addNode(text: String, parentNode: EditableNode?, reason: String?) {
        guard let parent = parentNode else { return }
        
        let angle = Double.random(in: 0...(2 * .pi))
        let distance: Double = 150
        let newX = parent.positionX + cos(angle) * distance
        let newY = parent.positionY + sin(angle) * distance
        
        let newNode = EditableNode(
            id: UUID(),
            text: text,
            positionX: newX,
            positionY: newY,
            isCenter: false,
            parentId: parent.id
        )
        
        nodes.append(newNode)
        
        let newConnection = EditableConnection(
            id: UUID(),
            fromNodeId: parent.id,
            toNodeId: newNode.id,
            reason: reason ?? ""
        )
        
        connections.append(newConnection)
    }
    
    private func saveChanges() {
        isSaving = true
        
        Task {
            do {
                // 新しいノードのみを保存
                let newNodes = nodes.filter { !existingNodeIds.contains($0.id) }
                let newConnections = connections.filter { !existingNodeIds.contains($0.toNodeId) }
                
                // ノードIDのマッピング（ローカルID -> サーバーID）
                var nodeIdMap: [UUID: UUID] = [:]
                
                // 既存ノードのIDはそのまま
                for nodeId in existingNodeIds {
                    nodeIdMap[nodeId] = nodeId
                }
                
                // 新しいノードを追加
                for node in newNodes {
                    let savedNode = try await PostService.shared.addNode(
                        postId: post.id,
                        text: node.text,
                        positionX: node.positionX,
                        positionY: node.positionY,
                        isCenter: false
                    )
                    nodeIdMap[node.id] = savedNode.id
                }
                
                // コネクションを追加
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
                
                print("✅ [EditPost] 保存成功")
            } catch {
                print("🔴 [EditPost] 保存エラー: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - ノード行（EditPostView用）
struct EditNodeRow: View {
    let node: EditableNode
    let isNew: Bool
    let isSelected: Bool
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        node.isCenter
                        ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(isNew ? Color.green : Color.clear, lineWidth: 2)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.text)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if node.isCenter {
                        Text("中心ノード")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if isNew {
                        Text("新規追加")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .foregroundColor(.purple)
            }
            .padding()
            .background(isSelected ? Color.purple.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - ノード追加シート
struct AddNodeSheet: View {
    let parentNode: EditableNode?
    var onAdd: (String, String?) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var nodeText = ""
    @State private var reason = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("新しいノード") {
                    TextField("ノードのテキスト", text: $nodeText)
                }
                
                Section("つながりの理由（任意）") {
                    TextField("なぜこのノードを追加？", text: $reason)
                }
                
                if let parent = parentNode {
                    Section {
                        Text("「\(parent.text)」から枝を伸ばします")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        onAdd(nodeText, reason.isEmpty ? nil : reason)
                        dismiss()
                    }
                    .disabled(nodeText.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
