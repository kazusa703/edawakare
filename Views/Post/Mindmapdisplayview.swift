// Views/Post/MindMapDisplayView.swift

import SwiftUI

// MARK: - マインドマップ表示View（閲覧専用・自由移動＆ズーム対応）
struct MindMapDisplayView: View {
    let post: Post
    var onShowReason: ((String) -> Void)?
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var longPressedConnectionId: UUID? = nil
    @State private var showReasonToast = false
    @State private var toastReason = ""
    @State private var toastPosition: CGPoint = .zero
    
    // ノード詳細表示用
    @State private var showDetailToast = false
    @State private var toastDetail = ""
    @State private var toastNodeName = ""
    
    var nodes: [Node] {
        post.nodes ?? []
    }
    
    var connections: [NodeConnection] {
        post.connections ?? []
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        longPressedConnectionId = nil
                        showReasonToast = false
                        showDetailToast = false
                    }
                
                ZStack {
                    ForEach(connections) { connection in
                        InteractiveConnectionLine(
                            connection: connection,
                            nodes: nodes,
                            isHighlighted: longPressedConnectionId == connection.id,
                            onTap: {
                                handleConnectionTap(connection)
                            },
                            onLongPress: { position in
                                handleConnectionLongPress(connection, at: position)
                            }
                        )
                    }
                    
                    ForEach(nodes) { node in
                        DisplayNodeView(
                            node: node,
                            centerNodeText: post.centerNodeText,
                            onLongPress: {
                                handleNodeLongPress(node)
                            }
                        )
                        .position(x: node.positionX, y: node.positionY)
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                
                // 理由トースト
                if showReasonToast && !toastReason.isEmpty {
                    ReasonToastView(
                        reason: toastReason,
                        onDismiss: {
                            withAnimation {
                                showReasonToast = false
                                longPressedConnectionId = nil
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }
                
                // ノード詳細トースト
                if showDetailToast && !toastDetail.isEmpty {
                    NodeDetailToastView(
                        nodeName: toastNodeName,
                        detail: toastDetail,
                        onDismiss: {
                            withAnimation {
                                showDetailToast = false
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, 0.3), 4.0)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
            .onAppear {
                centerContent(in: geometry.size)
            }
        }
        .clipped()
    }
    
    private func handleConnectionTap(_ connection: NodeConnection) {
        if let reason = connection.reason, !reason.isEmpty {
            onShowReason?(reason)
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            if longPressedConnectionId == connection.id {
                longPressedConnectionId = nil
            } else {
                longPressedConnectionId = connection.id
            }
        }
    }
    
    private func handleConnectionLongPress(_ connection: NodeConnection, at position: CGPoint) {
        if let reason = connection.reason, !reason.isEmpty {
            toastReason = reason
            toastPosition = position
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3)) {
                longPressedConnectionId = connection.id
                showReasonToast = true
                showDetailToast = false
            }
        }
    }
    
    private func handleNodeLongPress(_ node: Node) {
        if let detail = node.note, !detail.isEmpty {
            toastNodeName = node.isCenter ? post.centerNodeText : node.text
            toastDetail = detail
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3)) {
                showDetailToast = true
                showReasonToast = false
                longPressedConnectionId = nil
            }
        }
    }
    
    private func centerContent(in size: CGSize) {
        guard !nodes.isEmpty else { return }
        
        let avgX = nodes.map { $0.positionX }.reduce(0, +) / Double(nodes.count)
        let avgY = nodes.map { $0.positionY }.reduce(0, +) / Double(nodes.count)
        
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        offset = CGSize(
            width: centerX - avgX,
            height: centerY - avgY
        )
        lastOffset = offset
    }
}

// MARK: - 表示専用ノードView（スタイル対応）
struct DisplayNodeView: View {
    let node: Node
    let centerNodeText: String
    var onLongPress: (() -> Void)? = nil
    
    var displayText: String {
        node.isCenter ? centerNodeText : node.text
    }
    
    var nodeSize: CGFloat {
        node.isCenter ? 100 : 80
    }
    
    var hasDetail: Bool {
        if let detail = node.note {
            return !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }
    
    // スタイルを取得（保存されていればそれを使用、なければデフォルト）
    var nodeStyle: NodeStyleData {
        if let styleString = node.style,
           let data = styleString.data(using: .utf8),
           let json = try? JSONDecoder().decode(NodeStyleJSON.self, from: data) {
            return json.toNodeStyleData()
        }
        return node.isCenter ? .defaultCenter : .defaultChild
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(nodeStyle.fillColor.color)
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            
            Circle()
                .stroke(nodeStyle.borderColor.color, lineWidth: 2)
                .frame(width: nodeSize, height: nodeSize)
            
            Text(displayText)
                .font(.system(size: node.isCenter ? 14 : 12, weight: node.isCenter ? .bold : .medium))
                .foregroundColor(nodeStyle.textColor.color)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(width: nodeSize - 16)
            
            // 詳細ありバッジ
            if hasDetail {
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
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress?()
        }
    }
}

// MARK: - インタラクティブなコネクション線（スタイル対応）
struct InteractiveConnectionLine: View {
    let connection: NodeConnection
    let nodes: [Node]
    let isHighlighted: Bool
    let onTap: () -> Void
    let onLongPress: (CGPoint) -> Void
    
    @State private var isPressed = false
    
    var hasReason: Bool {
        if let reason = connection.reason {
            return !reason.isEmpty
        }
        return false
    }
    
    // スタイルを取得
    var connectionStyle: ConnectionStyleData {
        if let styleString = connection.style,
           let data = styleString.data(using: .utf8),
           let json = try? JSONDecoder().decode(ConnectionStyleJSON.self, from: data) {
            return json.toConnectionStyleData()
        }
        return .defaultStyle
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
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .stroke(
                    isHighlighted ? Color.pink : connectionStyle.lineColor.color,
                    style: StrokeStyle(
                        lineWidth: isHighlighted ? connectionStyle.lineWidth + 2 : connectionStyle.lineWidth,
                        lineCap: .round
                    )
                )
                
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .stroke(Color.clear, lineWidth: 44)
                .contentShape(
                    Path { path in
                        path.move(to: adjustedFromPoint)
                        path.addLine(to: adjustedToPoint)
                    }
                    .strokedPath(StrokeStyle(lineWidth: 44))
                )
                .onTapGesture {
                    onTap()
                }
                .onLongPressGesture(minimumDuration: 0.3) {
                    onLongPress(midPoint)
                }
                
                if hasReason {
                    ZStack {
                        Circle()
                            .fill(isHighlighted ? Color.pink : connectionStyle.lineColor.color)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                        
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .position(midPoint)
                    .scaleEffect(isHighlighted ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: isHighlighted)
                    .onTapGesture {
                        onTap()
                    }
                }
            }
        }
    }
}

// MARK: - 理由トースト表示
struct ReasonToastView: View {
    let reason: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "link")
                        .font(.headline)
                        .foregroundColor(.purple)
                    
                    Text("つながりの理由")
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
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }
}

// MARK: - ノード詳細トースト表示
struct NodeDetailToastView: View {
    let nodeName: String
    let detail: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text(nodeName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                
                Text(detail)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }
}

// MARK: - 理由表示ポップアップ
struct ReasonDisplayPopup: View {
    let reason: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("つながりの理由")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                
                Text(reason)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 25)
            )
            .padding(.horizontal, 32)
        }
    }
}
