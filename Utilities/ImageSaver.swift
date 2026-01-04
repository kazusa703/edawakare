// Utilities/ImageSaver.swift

import SwiftUI

class ImageSaver {
    static let shared = ImageSaver()
    private init() {}
    
    // マインドマップを画像として保存
    @MainActor
    func saveMindMapAsImage(post: Post, completion: @escaping (Bool, String) -> Void) {
        // マインドマップのViewを作成
        let mindMapView = MindMapImageView(post: post)
        
        // ImageRendererで画像に変換
        let renderer = ImageRenderer(content: mindMapView)
        renderer.scale = UIScreen.main.scale * 2  // 高解像度
        
        if let uiImage = renderer.uiImage {
            // カメラロールに保存
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            completion(true, "画像を保存しました")
        } else {
            completion(false, "画像の生成に失敗しました")
        }
    }
}

// MARK: - 画像出力用のマインドマップView
struct MindMapImageView: View {
    let post: Post
    
    var body: some View {
        ZStack {
            // 背景
            Color.white
            
            // 接続線
            ForEach(post.connections ?? []) { connection in
                ImageConnectionLine(
                    connection: connection,
                    nodes: post.nodes ?? []
                )
            }
            
            // ノード
            ForEach(post.nodes ?? []) { node in
                ImageNodeView(node: node, centerText: post.centerNodeText)
            }
            
            // ウォーターマーク
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("枝分かれ")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(8)
                }
            }
        }
        .frame(width: 400, height: 400)
    }
}

// MARK: - 画像用ノードView
struct ImageNodeView: View {
    let node: Node
    let centerText: String
    
    var nodeSize: CGFloat {
        node.isCenter ? 100 : 80
    }
    
    var displayText: String {
        node.isCenter ? centerText : node.text
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    node.isCenter
                        ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            if !node.isCenter {
                Circle()
                    .stroke(Color.purple.opacity(0.5), lineWidth: 2)
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
        .position(x: node.positionX, y: node.positionY)
    }
}

// MARK: - 画像用接続線View
struct ImageConnectionLine: View {
    let connection: NodeConnection
    let nodes: [Node]
    
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
            
            ZStack {
                Path { path in
                    path.move(to: adjustedFromPoint)
                    path.addLine(to: adjustedToPoint)
                }
                .stroke(Color.purple.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                // 矢印
                Path { path in
                    let arrowAngle: CGFloat = .pi / 6
                    let arrowSize: CGFloat = 12
                    
                    let point1 = CGPoint(
                        x: adjustedToPoint.x - arrowSize * cos(angle - arrowAngle),
                        y: adjustedToPoint.y - arrowSize * sin(angle - arrowAngle)
                    )
                    let point2 = CGPoint(
                        x: adjustedToPoint.x - arrowSize * cos(angle + arrowAngle),
                        y: adjustedToPoint.y - arrowSize * sin(angle + arrowAngle)
                    )
                    
                    path.move(to: adjustedToPoint)
                    path.addLine(to: point1)
                    path.move(to: adjustedToPoint)
                    path.addLine(to: point2)
                }
                .stroke(Color.purple.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
