// Views/Post/Components/NodeStyle.swift

import SwiftUI

// MARK: - ノードスタイル
struct NodeStyleData: Codable, Equatable {
    var fillColor: CodableColor
    var borderColor: CodableColor
    var textColor: CodableColor
    
    init(fillColor: Color = .purple, borderColor: Color = .purple, textColor: Color = .white) {
        self.fillColor = CodableColor(color: fillColor)
        self.borderColor = CodableColor(color: borderColor)
        self.textColor = CodableColor(color: textColor)
    }
    
    static let defaultCenter = NodeStyleData(
        fillColor: .purple,
        borderColor: .pink,
        textColor: .white
    )
    
    static let defaultChild = NodeStyleData(
        fillColor: Color(.secondarySystemBackground),
        borderColor: .purple,
        textColor: .primary
    )
}

// MARK: - 接続線スタイル
struct ConnectionStyleData: Codable, Equatable {
    var lineColor: CodableColor
    var lineWidth: CGFloat
    
    init(lineColor: Color = .purple, lineWidth: CGFloat = 2) {
        self.lineColor = CodableColor(color: lineColor)
        self.lineWidth = lineWidth
    }
    
    static let defaultStyle = ConnectionStyleData(
        lineColor: Color.purple.opacity(0.6),
        lineWidth: 2
    )
}

// MARK: - Codable Color
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double
    
    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - 編集可能ノード（スタイル付き）
struct StyledNode: Identifiable, Equatable {
    let id: UUID
    var text: String
    var positionX: Double
    var positionY: Double
    var isCenter: Bool
    var parentId: UUID?
    var style: NodeStyleData
    var note: String
    
    init(id: UUID = UUID(), text: String, positionX: Double, positionY: Double, isCenter: Bool, parentId: UUID? = nil, style: NodeStyleData? = nil, note: String = "") {
        self.id = id
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.isCenter = isCenter
        self.parentId = parentId
        self.style = style ?? (isCenter ? .defaultCenter : .defaultChild)
        self.note = note
    }
    
    var hasNote: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 編集可能接続線（スタイル付き）
struct StyledConnection: Identifiable, Equatable {
    let id: UUID
    let fromNodeId: UUID
    let toNodeId: UUID
    var reason: String
    var style: ConnectionStyleData
    
    init(id: UUID = UUID(), fromNodeId: UUID, toNodeId: UUID, reason: String = "", style: ConnectionStyleData = .defaultStyle) {
        self.id = id
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.reason = reason
        self.style = style
    }
}

// MARK: - 履歴管理用
struct MindMapState: Equatable {
    var nodes: [StyledNode]
    var connections: [StyledConnection]
    var centerNodeText: String
}

// MARK: - プリセットカラー
struct PresetColors {
    static let nodeColors: [Color] = [
        .purple, .pink, .blue, .green, .orange, .red, .yellow, .cyan, .mint, .indigo,
        Color(.systemGray), Color(.systemGray2), .white, .black
    ]
    
    static let lineColors: [Color] = [
        .purple, .pink, .blue, .green, .orange, .red, .gray, .black
    ]
}
