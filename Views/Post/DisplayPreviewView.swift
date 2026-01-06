// Views/Post/DisplayPreviewView.swift

import SwiftUI

struct DisplayPreviewView: View {
    let centerNodeText: String
    let nodes: [StyledNode]
    let connections: [StyledConnection]

    // 初期値（編集時用）
    var initialScale: Double = 1.0
    var initialOffsetX: Double = 0
    var initialOffsetY: Double = 0

    var onConfirm: (Double, Double, Double) -> Void
    var onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    // プレビューフレーム（フィード表示サイズ）
                    VStack {
                        Text("フィードでの表示プレビュー")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)

                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                .background(Color(.systemBackground))

                            // マインドマップ表示
                            ZStack {
                                ForEach(connections) { connection in
                                    DisplayPreviewConnectionLine(
                                        connection: connection,
                                        nodes: nodes,
                                        centerNodeText: centerNodeText
                                    )
                                }

                                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                                    DisplayPreviewNodeView(
                                        node: node,
                                        centerNodeText: centerNodeText,
                                        nodeIndex: index + 1
                                    )
                                }
                            }
                            .scaleEffect(scale)
                            .offset(offset)
                        }
                        .frame(width: geometry.size.width - 32, height: geometry.size.height * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )

                        Spacer()

                        // 操作説明
                        VStack(spacing: 8) {
                            HStack(spacing: 16) {
                                Label("ピンチでズーム", systemImage: "hand.pinch")
                                Label("ドラッグで移動", systemImage: "hand.draw")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 8)

                        // ボタン
                        HStack(spacing: 16) {
                            Button(action: resetView) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("リセット")
                                }
                                .font(.headline)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple, lineWidth: 2)
                                )
                            }

                            Button(action: confirmSettings) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("この表示で投稿")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("フィード表示設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                }
            }
            .onAppear {
                scale = initialScale
                offset = CGSize(width: initialOffsetX, height: initialOffsetY)
                lastOffset = offset
            }
        }
    }

    private func resetView() {
        withAnimation(.spring(response: 0.3)) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
        HapticManager.shared.lightImpact()
    }

    private func confirmSettings() {
        HapticManager.shared.success()
        onConfirm(Double(scale), Double(offset.width), Double(offset.height))
    }
}

// MARK: - プレビュー用ノードView
struct DisplayPreviewNodeView: View {
    let node: StyledNode
    let centerNodeText: String
    var nodeIndex: Int = 0

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
        .position(x: node.positionX, y: node.positionY)
    }
}

// MARK: - プレビュー用コネクション線
struct DisplayPreviewConnectionLine: View {
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

// MARK: - 既存投稿用の表示設定View（Node型対応）
struct DisplaySettingsView: View {
    let post: Post
    var onConfirm: (Double, Double, Double) -> Void
    var onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var nodes: [Node] {
        post.nodes ?? []
    }

    var connections: [NodeConnection] {
        post.connections ?? []
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    VStack {
                        Text("フィードでの表示プレビュー")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)

                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                .background(Color(.systemBackground))

                            // マインドマップ表示
                            ZStack {
                                ForEach(connections) { connection in
                                    SettingsConnectionLine(
                                        connection: connection,
                                        nodes: nodes,
                                        centerNodeText: post.centerNodeText
                                    )
                                }

                                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                                    SettingsNodeView(
                                        node: node,
                                        centerNodeText: post.centerNodeText,
                                        nodeIndex: index + 1
                                    )
                                }
                            }
                            .scaleEffect(scale)
                            .offset(offset)
                        }
                        .frame(width: geometry.size.width - 32, height: geometry.size.height * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )

                        Spacer()

                        VStack(spacing: 8) {
                            HStack(spacing: 16) {
                                Label("ピンチでズーム", systemImage: "hand.pinch")
                                Label("ドラッグで移動", systemImage: "hand.draw")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 8)

                        HStack(spacing: 16) {
                            Button(action: resetView) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("リセット")
                                }
                                .font(.headline)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple, lineWidth: 2)
                                )
                            }

                            Button(action: confirmSettings) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("この表示で保存")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("フィード表示設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                }
            }
            .onAppear {
                scale = post.displayScale
                offset = CGSize(width: post.displayOffsetX, height: post.displayOffsetY)
                lastOffset = offset
            }
        }
    }

    private func resetView() {
        withAnimation(.spring(response: 0.3)) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
        HapticManager.shared.lightImpact()
    }

    private func confirmSettings() {
        HapticManager.shared.success()
        onConfirm(Double(scale), Double(offset.width), Double(offset.height))
    }
}

// MARK: - 設定用ノードView（Node型対応）
struct SettingsNodeView: View {
    let node: Node
    let centerNodeText: String
    var nodeIndex: Int = 0

    var displayText: String {
        node.isCenter ? centerNodeText : node.text
    }

    var nodeSize: CGFloat {
        node.isCenter ? 100 : 80
    }

    var nodeStyle: NodeStyleData {
        if let styleString = node.style,
           let data = styleString.data(using: .utf8),
           let json = try? JSONDecoder().decode(NodeStyleJSON.self, from: data) {
            return json.toNodeStyleData()
        }
        return node.isCenter ? NodeStyleData.defaultCenter : NodeStyleData.defaultChild
    }

    var hasDetail: Bool {
        if let detail = node.note {
            return !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(nodeStyle.fillColor.color)
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            Circle()
                .stroke(nodeStyle.borderColor.color, lineWidth: 2)
                .frame(width: nodeSize, height: nodeSize)

            Text(displayText)
                .font(.system(size: node.isCenter ? 14 : 12))
                .fontWeight(node.isCenter ? .bold : .medium)
                .foregroundColor(nodeStyle.textColor.color)
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
        .position(x: node.positionX, y: node.positionY)
    }
}

// MARK: - 設定用コネクション線（NodeConnection型対応）
struct SettingsConnectionLine: View {
    let connection: NodeConnection
    let nodes: [Node]
    let centerNodeText: String

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
                    connectionStyle.lineColor.color,
                    style: StrokeStyle(lineWidth: connectionStyle.lineWidth, lineCap: .round)
                )

                if let reason = connection.reason, !reason.isEmpty {
                    ZStack {
                        Circle()
                            .fill(connectionStyle.lineColor.color)
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
