// Utilities/EditionColors.swift

import SwiftUI

/// ノード追加回（Edition）ごとの縁カラー定義
/// 100回分、101回目以降はループ
struct EditionColors {
    
    static let colors: [Color] = [
        // 1-10: 基本色
        Color.white,                           // 1: 白（初回投稿）
        Color(hex: "FF3B30"),                  // 2: 赤
        Color(hex: "007AFF"),                  // 3: 青
        Color(hex: "34C759"),                  // 4: 緑
        Color(hex: "FF9500"),                  // 5: オレンジ
        Color(hex: "AF52DE"),                  // 6: 紫
        Color(hex: "FF2D55"),                  // 7: ピンク
        Color(hex: "5AC8FA"),                  // 8: シアン
        Color(hex: "FFCC00"),                  // 9: 黄
        Color(hex: "5856D6"),                  // 10: インディゴ
        
        // 11-20: セカンダリ色
        Color(hex: "00C7BE"),                  // 11: ミント
        Color(hex: "A2845E"),                  // 12: ブラウン
        Color(hex: "B4D455"),                  // 13: ライム
        Color(hex: "FF6B6B"),                  // 14: コーラル
        Color(hex: "87CEEB"),                  // 15: スカイ
        Color(hex: "E6E6FA"),                  // 16: ラベンダー
        Color(hex: "FFD700"),                  // 17: ゴールド
        Color(hex: "008080"),                  // 18: ティール
        Color(hex: "FA8072"),                  // 19: サーモン
        Color(hex: "708090"),                  // 20: スレート
        
        // 21-30: 赤系バリエーション
        Color(hex: "DC143C"),                  // 21: クリムゾン
        Color(hex: "B22222"),                  // 22: ファイアブリック
        Color(hex: "CD5C5C"),                  // 23: インディアンレッド
        Color(hex: "F08080"),                  // 24: ライトコーラル
        Color(hex: "E9967A"),                  // 25: ダークサーモン
        Color(hex: "FF6347"),                  // 26: トマト
        Color(hex: "FF4500"),                  // 27: オレンジレッド
        Color(hex: "FF7F50"),                  // 28: コーラルオレンジ
        Color(hex: "FF8C00"),                  // 29: ダークオレンジ
        Color(hex: "FFA07A"),                  // 30: ライトサーモン
        
        // 31-40: 青系バリエーション
        Color(hex: "4169E1"),                  // 31: ロイヤルブルー
        Color(hex: "6495ED"),                  // 32: コーンフラワー
        Color(hex: "00BFFF"),                  // 33: ディープスカイ
        Color(hex: "1E90FF"),                  // 34: ドジャーブルー
        Color(hex: "ADD8E6"),                  // 35: ライトブルー
        Color(hex: "B0E0E6"),                  // 36: パウダーブルー
        Color(hex: "87CEFA"),                  // 37: ライトスカイ
        Color(hex: "4682B4"),                  // 38: スチールブルー
        Color(hex: "5F9EA0"),                  // 39: カデットブルー
        Color(hex: "00CED1"),                  // 40: ダークターコイズ
        
        // 41-50: 緑系バリエーション
        Color(hex: "32CD32"),                  // 41: ライムグリーン
        Color(hex: "00FA9A"),                  // 42: ミディアムスプリング
        Color(hex: "00FF7F"),                  // 43: スプリンググリーン
        Color(hex: "3CB371"),                  // 44: ミディアムシー
        Color(hex: "2E8B57"),                  // 45: シーグリーン
        Color(hex: "228B22"),                  // 46: フォレスト
        Color(hex: "6B8E23"),                  // 47: オリーブドラブ
        Color(hex: "9ACD32"),                  // 48: イエローグリーン
        Color(hex: "ADFF2F"),                  // 49: グリーンイエロー
        Color(hex: "7CFC00"),                  // 50: ローングリーン
        
        // 51-60: 紫・ピンク系
        Color(hex: "9370DB"),                  // 51: ミディアムパープル
        Color(hex: "8A2BE2"),                  // 52: ブルーバイオレット
        Color(hex: "9400D3"),                  // 53: ダークバイオレット
        Color(hex: "BA55D3"),                  // 54: ミディアムオーキッド
        Color(hex: "DA70D6"),                  // 55: オーキッド
        Color(hex: "EE82EE"),                  // 56: バイオレット
        Color(hex: "DDA0DD"),                  // 57: プラム
        Color(hex: "FF69B4"),                  // 58: ホットピンク
        Color(hex: "FFB6C1"),                  // 59: ライトピンク
        Color(hex: "DB7093"),                  // 60: ペールバイオレットレッド
        
        // 61-70: 赤青交互パターン
        Color(hex: "E53935"),                  // 61: 赤1
        Color(hex: "1E88E5"),                  // 62: 青1
        Color(hex: "C62828"),                  // 63: 赤2
        Color(hex: "1565C0"),                  // 64: 青2
        Color(hex: "B71C1C"),                  // 65: 赤3
        Color(hex: "0D47A1"),                  // 66: 青3
        Color(hex: "D32F2F"),                  // 67: 赤4
        Color(hex: "1976D2"),                  // 68: 青4
        Color(hex: "F44336"),                  // 69: 赤5
        Color(hex: "2196F3"),                  // 70: 青5
        
        // 71-80: 暖色・寒色交互
        Color(hex: "FF5722"),                  // 71: ディープオレンジ
        Color(hex: "03A9F4"),                  // 72: ライトブルー
        Color(hex: "FF9800"),                  // 73: オレンジ
        Color(hex: "00BCD4"),                  // 74: シアン
        Color(hex: "FFC107"),                  // 75: アンバー
        Color(hex: "009688"),                  // 76: ティール
        Color(hex: "FFEB3B"),                  // 77: イエロー
        Color(hex: "4CAF50"),                  // 78: グリーン
        Color(hex: "FF5252"),                  // 79: レッドアクセント
        Color(hex: "448AFF"),                  // 80: ブルーアクセント
        
        // 81-90: パステル系
        Color(hex: "FFCDD2"),                  // 81: パステルレッド
        Color(hex: "BBDEFB"),                  // 82: パステルブルー
        Color(hex: "C8E6C9"),                  // 83: パステルグリーン
        Color(hex: "FFF9C4"),                  // 84: パステルイエロー
        Color(hex: "E1BEE7"),                  // 85: パステルパープル
        Color(hex: "FFCCBC"),                  // 86: パステルオレンジ
        Color(hex: "B2EBF2"),                  // 87: パステルシアン
        Color(hex: "F8BBD9"),                  // 88: パステルピンク
        Color(hex: "DCEDC8"),                  // 89: パステルライム
        Color(hex: "D1C4E9"),                  // 90: パステルディープパープル
        
        // 91-100: ダーク系
        Color(hex: "212121"),                  // 91: グレー900
        Color(hex: "37474F"),                  // 92: ブルーグレー800
        Color(hex: "4E342E"),                  // 93: ブラウン800
        Color(hex: "1B5E20"),                  // 94: グリーン900
        Color(hex: "0D47A1"),                  // 95: ブルー900
        Color(hex: "4A148C"),                  // 96: パープル900
        Color(hex: "880E4F"),                  // 97: ピンク900
        Color(hex: "E65100"),                  // 98: オレンジ900
        Color(hex: "263238"),                  // 99: ブルーグレー900
        Color(hex: "3E2723"),                  // 100: ブラウン900
    ]
    
    /// Edition番号から色を取得（1始まり、101以降はループ）
    static func color(for edition: Int) -> Color {
        guard edition > 0 else { return colors[0] }
        let index = (edition - 1) % colors.count
        return colors[index]
    }
    
    /// Edition番号から色名を取得（デバッグ用）
    static func colorName(for edition: Int) -> String {
        let names = [
            "白", "赤", "青", "緑", "オレンジ", "紫", "ピンク", "シアン", "黄", "インディゴ",
            "ミント", "ブラウン", "ライム", "コーラル", "スカイ", "ラベンダー", "ゴールド", "ティール", "サーモン", "スレート",
            "クリムゾン", "ファイアブリック", "インディアンレッド", "ライトコーラル", "ダークサーモン", "トマト", "オレンジレッド", "コーラルオレンジ", "ダークオレンジ", "ライトサーモン",
            "ロイヤルブルー", "コーンフラワー", "ディープスカイ", "ドジャーブルー", "ライトブルー", "パウダーブルー", "ライトスカイ", "スチールブルー", "カデットブルー", "ダークターコイズ",
            "ライムグリーン", "ミディアムスプリング", "スプリンググリーン", "ミディアムシー", "シーグリーン", "フォレスト", "オリーブドラブ", "イエローグリーン", "グリーンイエロー", "ローングリーン",
            "ミディアムパープル", "ブルーバイオレット", "ダークバイオレット", "ミディアムオーキッド", "オーキッド", "バイオレット", "プラム", "ホットピンク", "ライトピンク", "ペールバイオレットレッド",
            "赤1", "青1", "赤2", "青2", "赤3", "青3", "赤4", "青4", "赤5", "青5",
            "ディープオレンジ", "ライトブルー", "オレンジ", "シアン", "アンバー", "ティール", "イエロー", "グリーン", "レッドアクセント", "ブルーアクセント",
            "パステルレッド", "パステルブルー", "パステルグリーン", "パステルイエロー", "パステルパープル", "パステルオレンジ", "パステルシアン", "パステルピンク", "パステルライム", "パステルディープパープル",
            "グレー900", "ブルーグレー800", "ブラウン800", "グリーン900", "ブルー900", "パープル900", "ピンク900", "オレンジ900", "ブルーグレー900", "ブラウン900"
        ]
        guard edition > 0 else { return names[0] }
        let index = (edition - 1) % names.count
        return names[index]
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
