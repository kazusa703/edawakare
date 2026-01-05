// Services/StyleManager.swift

import SwiftUI
import Combine

// MARK: - お気に入りスタイル
struct FavoriteStyle: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var nodeStyle: SavedNodeStyle
    var connectionStyle: SavedConnectionStyle
    
    init(id: UUID = UUID(), name: String = "スタイル", nodeStyle: SavedNodeStyle = .default, connectionStyle: SavedConnectionStyle = .default) {
        self.id = id
        self.name = name
        self.nodeStyle = nodeStyle
        self.connectionStyle = connectionStyle
    }
    
    static let empty = FavoriteStyle(name: "未設定")
}

// MARK: - 保存用ノードスタイル
struct SavedNodeStyle: Codable, Equatable {
    var fillRed: Double
    var fillGreen: Double
    var fillBlue: Double
    var fillOpacity: Double
    var borderRed: Double
    var borderGreen: Double
    var borderBlue: Double
    var borderOpacity: Double
    var textRed: Double
    var textGreen: Double
    var textBlue: Double
    var textOpacity: Double
    
    init(fillColor: Color = .purple, borderColor: Color = .pink, textColor: Color = .white) {
        let fill = UIColor(fillColor)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        fill.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        self.fillRed = Double(fr)
        self.fillGreen = Double(fg)
        self.fillBlue = Double(fb)
        self.fillOpacity = Double(fa)
        
        let border = UIColor(borderColor)
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        border.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        self.borderRed = Double(br)
        self.borderGreen = Double(bg)
        self.borderBlue = Double(bb)
        self.borderOpacity = Double(ba)
        
        let text = UIColor(textColor)
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        text.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        self.textRed = Double(tr)
        self.textGreen = Double(tg)
        self.textBlue = Double(tb)
        self.textOpacity = Double(ta)
    }
    
    var fillColor: Color {
        Color(red: fillRed, green: fillGreen, blue: fillBlue, opacity: fillOpacity)
    }
    
    var borderColor: Color {
        Color(red: borderRed, green: borderGreen, blue: borderBlue, opacity: borderOpacity)
    }
    
    var textColor: Color {
        Color(red: textRed, green: textGreen, blue: textBlue, opacity: textOpacity)
    }
    
    static let `default` = SavedNodeStyle(fillColor: .purple, borderColor: .pink, textColor: .white)
}

// MARK: - 保存用接続線スタイル
struct SavedConnectionStyle: Codable, Equatable {
    var lineRed: Double
    var lineGreen: Double
    var lineBlue: Double
    var lineOpacity: Double
    var lineWidth: CGFloat
    
    init(lineColor: Color = .purple, lineWidth: CGFloat = 2.0) {
        let line = UIColor(lineColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        line.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.lineRed = Double(r)
        self.lineGreen = Double(g)
        self.lineBlue = Double(b)
        self.lineOpacity = Double(a)
        self.lineWidth = lineWidth
    }
    
    var lineColor: Color {
        Color(red: lineRed, green: lineGreen, blue: lineBlue, opacity: lineOpacity)
    }
    
    static let `default` = SavedConnectionStyle(lineColor: .purple, lineWidth: 2.0)
}

// MARK: - スタイルマネージャー
class StyleManager: ObservableObject {
    static let shared = StyleManager()
    
    private let key = "favoriteStyles"
    
    @Published var favoriteStyles: [FavoriteStyle] = []
    
    private init() {
        loadStyles()
    }
    
    // MARK: - 読込
    func loadStyles() {
        if let data = UserDefaults.standard.data(forKey: key),
           let styles = try? JSONDecoder().decode([FavoriteStyle].self, from: data) {
            favoriteStyles = styles
        } else {
            // 初期状態：空の3スロット
            favoriteStyles = [
                FavoriteStyle(name: "スタイル 1"),
                FavoriteStyle(name: "スタイル 2"),
                FavoriteStyle(name: "スタイル 3")
            ]
            saveStyles()
        }
    }
    
    // MARK: - 保存
    func saveStyles() {
        if let data = try? JSONEncoder().encode(favoriteStyles) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - スロットに保存
    func saveToSlot(_ slot: Int, style: FavoriteStyle) {
        guard slot >= 0 && slot < favoriteStyles.count else { return }
        favoriteStyles[slot] = style
        saveStyles()
    }
    
    // MARK: - スロットから取得
    func getStyle(slot: Int) -> FavoriteStyle? {
        guard slot >= 0 && slot < favoriteStyles.count else { return nil }
        return favoriteStyles[slot]
    }
    
    // MARK: - 現在のスタイルから FavoriteStyle を作成
    func createFavoriteStyle(
        name: String,
        fillColor: Color,
        borderColor: Color,
        textColor: Color,
        lineColor: Color,
        lineWidth: CGFloat
    ) -> FavoriteStyle {
        FavoriteStyle(
            name: name,
            nodeStyle: SavedNodeStyle(fillColor: fillColor, borderColor: borderColor, textColor: textColor),
            connectionStyle: SavedConnectionStyle(lineColor: lineColor, lineWidth: lineWidth)
        )
    }
    
    // MARK: - スロットが設定済みか
    func isSlotConfigured(_ slot: Int) -> Bool {
        guard slot >= 0 && slot < favoriteStyles.count else { return false }
        let style = favoriteStyles[slot]
        // デフォルトと異なれば設定済み
        return style.nodeStyle != .default || style.connectionStyle != .default
    }
}
