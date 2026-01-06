// Views/Components/SharedColorPicker.swift

import SwiftUI

// MARK: - 共通カラーピッカー行
struct SharedColorPickerRow: View {
    let title: String
    @Binding var selectedColor: Color
    let colors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Circle()
                    .fill(selectedColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                        Button(action: { selectedColor = color }) {
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            ColorUtils.isEqual(selectedColor, color) ? Color.blue : Color.gray.opacity(0.3),
                                            lineWidth: ColorUtils.isEqual(selectedColor, color) ? 3 : 1
                                        )
                                )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - カラー比較ユーティリティ
struct ColorUtils {
    static func isEqual(_ c1: Color, _ c2: Color) -> Bool {
        let uiColor1 = UIColor(c1)
        let uiColor2 = UIColor(c2)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
}

// MARK: - 共通カラーオプション
struct AppColors {
    static let pickerColors: [Color] = [
        .purple, .pink, .blue, .green, .orange, .red, .yellow, .cyan, .mint, .indigo,
        Color(.systemGray), .white, .black
    ]
    
    static let primaryGradient = LinearGradient(
        colors: [.purple, .pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let horizontalGradient = LinearGradient(
        colors: [.purple, .pink],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let disabledGradient = LinearGradient(
        colors: [.gray],
        startPoint: .leading,
        endPoint: .trailing
    )
}
