// Views/Post/Components/PostPreviewView.swift

import SwiftUI

struct PostPreviewView: View {
    @Environment(\.dismiss) var dismiss
    
    let centerNodeText: String
    let nodes: [StyledNode]
    let connections: [StyledConnection]
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showNotePopup = false
    @State private var selectedNote = ""
    @State private var selectedNodeName = ""
    
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    ZStack {
                        ForEach(connections) { connection in
                            PreviewConnectionLine(
                                connection: connection,
                                nodes: nodes,
                                centerNodeText: centerNodeText
                            )
                        }
                        
                        ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                            PreviewNodeView(
                                node: node,
                                centerNodeText: centerNodeText,
                                nodeIndex: index + 1,
                                onLongPress: {
                                    if node.hasNote {
                                        selectedNote = node.note
                                        selectedNodeName = node.isCenter ? centerNodeText : node.text
                                        showNotePopup = true
                                        HapticManager.shared.lightImpact()
                                    }
                                }
                            )
                        }
                    }
                    .scaleEffect(scale * gestureScale)
                    .offset(
                        x: offset.width + gestureOffset.width,
                        y: offset.height + gestureOffset.height
                    )
                    .simultaneousGesture(
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
                            .updating($gestureOffset) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                offset = CGSize(
                                    width: offset.width + value.translation.width,
                                    height: offset.height + value.translation.height
                                )
                            }
                    )
                }
            }
            .navigationTitle("プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: resetZoom) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                    }
                }
            }
            .overlay {
                if showNotePopup {
                    NoteDisplayPopup(
                        nodeName: selectedNodeName,
                        note: selectedNote,
                        onDismiss: { showNotePopup = false }
                    )
                }
            }
        }
    }
    
    private func resetZoom() {
        withAnimation(.spring(response: 0.3)) {
            scale = 1.0
            offset = .zero
        }
    }
}

// MARK: - プレビュー用ノードView
struct PreviewNodeView: View {
    let node: StyledNode
    let centerNodeText: String
    let nodeIndex: Int
    var onLongPress: () -> Void
    
    var displayText: String {
        node.isCenter ? centerNodeText : node.text
    }
    
    var nodeSize: CGFloat {
        node.isCenter ? 100 : 80
    }
    
    var body: some View {
        ZStack {
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
            
            if node.hasNote {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                .offset(x: (nodeSize / 2) - 8, y: -(nodeSize / 2) + 8)
            }
        }
        .position(x: node.positionX, y: node.positionY)
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
    }
}

// MARK: - プレビュー用接続線
struct PreviewConnectionLine: View {
    let connection: StyledConnection
    let nodes: [StyledNode]
    let centerNodeText: String
    
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
            
            Path { path in
                path.move(to: adjustedFromPoint)
                path.addLine(to: adjustedToPoint)
            }
            .stroke(
                connection.style.lineColor.color,
                style: StrokeStyle(lineWidth: connection.style.lineWidth, lineCap: .round)
            )
        }
    }
}
