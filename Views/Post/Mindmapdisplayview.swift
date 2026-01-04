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
    
    // 長押し用
    @State private var longPressedConnectionId: UUID? = nil
    @State private var showReasonToast = false
    @State private var toastReason = ""
    @State private var toastPosition: CGPoint = .zero
    
    var nodes: [Node] {
        post.nodes ?? []
    }
    
    var connections: [NodeConnection] {
        post.connections ?? []
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景（タップで選択解除）
                Color(.systemBackground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        longPressedConnectionId = nil
                        showReasonToast = false
                    }
                
                // コンテンツ
                ZStack {
                    // コネクション（線）
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
                    
                    // ノード
                    ForEach(nodes) { node in
                        DisplayNodeView(node: node, centerNodeText: post.centerNodeText)
                            .position(x: node.positionX, y: node.positionY)
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                
                // 理由トースト表示
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
            }
            // ピンチでズーム
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
            // ドラッグで移動
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
            // ダブルタップでリセット
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
            .onAppear {
                // 初期位置を中央に調整
                centerContent(in: geometry.size)
            }
        }
        .clipped()
    }
    
    // MARK: - コネクションタップ処理
    private func handleConnectionTap(_ connection: NodeConnection) {
        if let reason = connection.reason, !reason.isEmpty {
            // ポップアップで表示（PostDetailViewのonShowReasonを使用）
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
    
    // MARK: - コネクション長押し処理
    private func handleConnectionLongPress(_ connection: NodeConnection, at position: CGPoint) {
        if let reason = connection.reason, !reason.isEmpty {
            toastReason = reason
            toastPosition = position
            
            // 触覚フィードバック
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3)) {
                longPressedConnectionId = connection.id
                showReasonToast = true
            }
        }
    }
    
    // MARK: - コンテンツを中央に配置
    private func centerContent(in size: CGSize) {
        guard !nodes.isEmpty else { return }
        
        // ノードの重心を計算
        let avgX = nodes.map { $0.positionX }.reduce(0, +) / Double(nodes.count)
        let avgY = nodes.map { $0.positionY }.reduce(0, +) / Double(nodes.count)
        
        // 画面中央との差分をオフセットに
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        offset = CGSize(
            width: centerX - avgX,
            height: centerY - avgY
        )
        lastOffset = offset
    }
}

// MARK: - 表示専用ノードView
struct DisplayNodeView: View {
    let node: Node
    let centerNodeText: String
    
    var displayText: String {
        node.isCenter ? centerNodeText : node.text
    }
    
    var nodeSize: CGFloat {
        node.isCenter ? 100 : 80
    }
    
    var body: some View {
        ZStack {
            // ノード背景
            Circle()
                .fill(
                    node.isCenter
                        ? LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [Color(.secondarySystemBackground)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            
            // 枠線（子ノードのみ）
            if !node.isCenter {
                Circle()
                    .stroke(Color.purple.opacity(0.4), lineWidth: 2)
                    .frame(width: nodeSize, height: nodeSize)
            }
            
            // テキスト
            Text(displayText)
                .font(.system(size: node.isCenter ? 14 : 12, weight: node.isCenter ? .bold : .medium))
                .foregroundColor(node.isCenter ? .white : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(width: nodeSize - 16)
        }
    }
}

// MARK: - インタラクティブなコネクション線
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
    
    var body: some View {
        if let fromNode = nodes.first(where: { $0.id == connection.fromNodeId }),
           let toNode = nodes.first(where: { $0.id == connection.toNodeId }) {
            
            let fromPoint = CGPoint(x: fromNode.positionX, y: fromNode.positionY)
            let toPoint = CGPoint(x: toNode.positionX, y: toNode.positionY)
            
            // ノードの半径を考慮して線の端点を調整
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
                // メインの線
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .stroke(
                    isHighlighted ? Color.pink : (hasReason ? Color.purple : Color.purple.opacity(0.4)),
                    style: StrokeStyle(
                        lineWidth: isHighlighted ? 5 : (hasReason ? 3 : 2),
                        lineCap: .round
                    )
                )
                
                // 矢印
                ArrowHeadDisplay(
                    at: adjustedToPoint,
                    angle: angle,
                    size: 12,
                    color: isHighlighted ? Color.pink : Color.purple.opacity(0.6)
                )
                
                // タップ領域（透明で広め）
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
                
                // 理由がある場合のインジケーター
                if hasReason {
                    ZStack {
                        Circle()
                            .fill(isHighlighted ? Color.pink : Color.purple)
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

// MARK: - 矢印ヘッド
struct ArrowHeadDisplay: View {
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
        .onTapGesture {
            // 背景タップで閉じる
        }
    }
}

// MARK: - 理由表示ポップアップ（PostDetailViewで使用）
struct ReasonDisplayPopup: View {
    let reason: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // 背景オーバーレイ
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            // ポップアップカード
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
