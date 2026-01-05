// Views/Post/Components/PostPreviewView.swift

import SwiftUI

struct PostPreviewView: View {
    @Environment(\.dismiss) var dismiss
    
    let centerNodeText: String
    let nodes: [StyledNode]
    let connections: [StyledConnection]
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showNumbers = true
    
    @GestureState private var gestureScale: CGFloat = 1.0
    
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
                                showNumber: showNumbers
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
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
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
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNumbers.toggle()
                            }
                        }) {
                            Image(systemName: showNumbers ? "number.circle.fill" : "number.circle")
                                .font(.system(size: 18))
                                .foregroundColor(showNumbers ? .purple : .gray)
                        }
                        
                        Button(action: resetZoom) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14))
                        }
                    }
                }
            }
        }
    }
    
    private func resetZoom() {
        withAnimation(.spring(response: 0.3)) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}

// MARK: - プレビュー用ノードView
struct PreviewNodeView: View {
    let node: StyledNode
    let centerNodeText: String
    let nodeIndex: Int
    var showNumber: Bool = true
    
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
            
            if showNumber {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 24, height: 24)
                    
                    Text("\(nodeIndex)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: -(nodeSize / 2) + 8, y: -(nodeSize / 2) + 8)
            }
        }
        .position(x: node.positionX, y: node.positionY)
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
        }
    }
}
