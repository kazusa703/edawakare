// Views/Post/MindMapView.swift

import SwiftUI

struct MindMapView: View {
    let nodes: [Node]
    let connections: [NodeConnection]
    @Binding var selectedConnection: NodeConnection?
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(connections) { connection in
                    ConnectionLineView(connection: connection, nodes: nodes, isSelected: selectedConnection?.id == connection.id) {
                        withAnimation { selectedConnection = connection }
                    }
                }
                
                ForEach(nodes) { node in
                    NodeView(node: node)
                        .position(x: node.positionX, y: node.positionY)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, 0.5), 3.0)
                    }
                    .onEnded { _ in lastScale = 1.0 }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
        }
    }
}

struct NodeView: View {
    let node: Node
    
    var body: some View {
        ZStack {
            Circle()
                .fill(node.isCenter
                    ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            if !node.isCenter {
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                    .frame(width: nodeSize, height: nodeSize)
            }
            
            Text(node.text)
                .font(.system(size: fontSize))
                .fontWeight(node.isCenter ? .bold : .medium)
                .foregroundColor(node.isCenter ? .white : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(width: nodeSize - 16)
        }
    }
    
    private var nodeSize: CGFloat { node.isCenter ? 100 : 80 }
    private var fontSize: CGFloat { node.isCenter ? 14 : 12 }
}

struct ConnectionLineView: View {
    let connection: NodeConnection
    let nodes: [Node]
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        if let fromNode = nodes.first(where: { $0.id == connection.fromNodeId }),
           let toNode = nodes.first(where: { $0.id == connection.toNodeId }) {
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: fromNode.positionX, y: fromNode.positionY))
                    path.addLine(to: CGPoint(x: toNode.positionX, y: toNode.positionY))
                }
                .stroke(isSelected ? Color.pink : Color.purple.opacity(0.5), style: StrokeStyle(lineWidth: isSelected ? 4 : 2, lineCap: .round))
                
                if connection.reason != nil && !connection.reason!.isEmpty {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 12, height: 12)
                        .overlay(Image(systemName: "info").font(.system(size: 8)).foregroundColor(.white))
                        .position(x: (fromNode.positionX + toNode.positionX) / 2, y: (fromNode.positionY + toNode.positionY) / 2)
                        .onTapGesture { onTap() }
                }
            }
        }
    }
}
