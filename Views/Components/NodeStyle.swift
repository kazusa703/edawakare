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
    var detail: String  // ノードの詳細（200文字まで）
    
    var hasDetail: Bool {
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(id: UUID = UUID(), text: String, positionX: Double, positionY: Double, isCenter: Bool, parentId: UUID? = nil, style: NodeStyleData? = nil, detail: String = "") {
        self.id = id
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.isCenter = isCenter
        self.parentId = parentId
        self.style = style ?? (isCenter ? .defaultCenter : .defaultChild)
        self.detail = detail
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

// MARK: - DB保存用スタイルJSON
struct NodeStyleJSON: Codable {
    let fillRed: Double
    let fillGreen: Double
    let fillBlue: Double
    let fillOpacity: Double
    let borderRed: Double
    let borderGreen: Double
    let borderBlue: Double
    let borderOpacity: Double
    let textRed: Double
    let textGreen: Double
    let textBlue: Double
    let textOpacity: Double
    
    init(from style: NodeStyleData) {
        self.fillRed = style.fillColor.red
        self.fillGreen = style.fillColor.green
        self.fillBlue = style.fillColor.blue
        self.fillOpacity = style.fillColor.opacity
        self.borderRed = style.borderColor.red
        self.borderGreen = style.borderColor.green
        self.borderBlue = style.borderColor.blue
        self.borderOpacity = style.borderColor.opacity
        self.textRed = style.textColor.red
        self.textGreen = style.textColor.green
        self.textBlue = style.textColor.blue
        self.textOpacity = style.textColor.opacity
    }
    
    func toNodeStyleData() -> NodeStyleData {
        NodeStyleData(
            fillColor: Color(red: fillRed, green: fillGreen, blue: fillBlue, opacity: fillOpacity),
            borderColor: Color(red: borderRed, green: borderGreen, blue: borderBlue, opacity: borderOpacity),
            textColor: Color(red: textRed, green: textGreen, blue: textBlue, opacity: textOpacity)
        )
    }
}

struct ConnectionStyleJSON: Codable {
    let lineRed: Double
    let lineGreen: Double
    let lineBlue: Double
    let lineOpacity: Double
    let lineWidth: Double
    
    init(from style: ConnectionStyleData) {
        self.lineRed = style.lineColor.red
        self.lineGreen = style.lineColor.green
        self.lineBlue = style.lineColor.blue
        self.lineOpacity = style.lineColor.opacity
        self.lineWidth = Double(style.lineWidth)
    }
    
    func toConnectionStyleData() -> ConnectionStyleData {
        ConnectionStyleData(
            lineColor: Color(red: lineRed, green: lineGreen, blue: lineBlue, opacity: lineOpacity),
            lineWidth: CGFloat(lineWidth)
        )
    }
}
