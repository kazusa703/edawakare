// Views/Post/Components/UnifyStyleView.swift

import SwiftUI

struct UnifyStyleView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var styleManager = StyleManager.shared
    
    @Binding var nodes: [StyledNode]
    @Binding var connections: [StyledConnection]
    let centerNodeText: String
    
    @State private var fillColor: Color = .purple
    @State private var borderColor: Color = .pink
    @State private var textColor: Color = .white
    @State private var lineColor: Color = .purple
    @State private var lineWidth: CGFloat = 2.0
    
    let colorOptions: [Color] = [
        .purple, .pink, .blue, .green, .orange, .red, .yellow, .cyan, .mint, .indigo,
        Color(.systemGray), .white, .black
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // お気に入りスタイル選択セクション
                    VStack(alignment: .leading, spacing: 12) {
                        Text("お気に入りスタイル")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(Array(styleManager.favoriteStyles.enumerated()), id: \.element.id) { index, style in
                                FavoriteStyleButton(
                                    style: style,
                                    isConfigured: styleManager.isSlotConfigured(index),
                                    onTap: {
                                        applyFavoriteStyle(style)
                                    }
                                )
                            }
                        }
                        
                        Text("タップで適用")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // ノードの色セクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ノードの色")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            UnifyColorPickerRow(
                                title: "塗りつぶし",
                                selectedColor: $fillColor,
                                colors: colorOptions
                            )
                            
                            Divider()
                            
                            UnifyColorPickerRow(
                                title: "縁の色",
                                selectedColor: $borderColor,
                                colors: colorOptions
                            )
                            
                            Divider()
                            
                            UnifyColorPickerRow(
                                title: "文字の色",
                                selectedColor: $textColor,
                                colors: colorOptions
                            )
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // 線のスタイルセクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("線のスタイル")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            UnifyColorPickerRow(
                                title: "線の色",
                                selectedColor: $lineColor,
                                colors: colorOptions
                            )
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("線の太さ")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(lineWidth, specifier: "%.1f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $lineWidth, in: 1...6, step: 0.5)
                                    .tint(.purple)
                                
                                HStack {
                                    ForEach([1.0, 2.0, 3.0, 4.0, 5.0, 6.0], id: \.self) { width in
                                        Button(action: { lineWidth = width }) {
                                            Text("\(Int(width))")
                                                .font(.caption)
                                                .fontWeight(lineWidth == width ? .bold : .regular)
                                                .foregroundColor(lineWidth == width ? .white : .primary)
                                                .frame(width: 36, height: 28)
                                                .background(lineWidth == width ? Color.purple : Color(.tertiarySystemBackground))
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // プレビューセクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("プレビュー")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            // 線
                            Path { path in
                                path.move(to: CGPoint(x: 100, y: 80))
                                path.addLine(to: CGPoint(x: 200, y: 80))
                            }
                            .stroke(lineColor, lineWidth: lineWidth)
                            
                            // 親ノード
                            Circle()
                                .fill(fillColor)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(borderColor, lineWidth: 2)
                                )
                                .overlay(
                                    Text("親")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(textColor)
                                )
                                .position(x: 80, y: 80)
                            
                            // 子ノード
                            Circle()
                                .fill(fillColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(borderColor, lineWidth: 2)
                                )
                                .overlay(
                                    Text("子")
                                        .font(.system(size: 12))
                                        .foregroundColor(textColor)
                                )
                                .position(x: 220, y: 80)
                        }
                        .frame(height: 140)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // 適用ボタン
                    Button(action: applyToAll) {
                        Text("すべてに適用")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("統一スタイル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyFavoriteStyle(_ style: FavoriteStyle) {
        fillColor = style.nodeStyle.fillColor
        borderColor = style.nodeStyle.borderColor
        textColor = style.nodeStyle.textColor
        lineColor = style.connectionStyle.lineColor
        lineWidth = style.connectionStyle.lineWidth
        
        HapticManager.shared.lightImpact()
    }
    
    private func applyToAll() {
        for index in nodes.indices {
            nodes[index].style = NodeStyleData(
                fillColor: fillColor,
                borderColor: borderColor,
                textColor: textColor
            )
        }
        
        for index in connections.indices {
            connections[index].style = ConnectionStyleData(
                lineColor: lineColor,
                lineWidth: lineWidth
            )
        }
        
        HapticManager.shared.success()
        dismiss()
    }
}

// MARK: - お気に入りスタイルボタン
struct FavoriteStyleButton: View {
    let style: FavoriteStyle
    let isConfigured: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isConfigured ? style.nodeStyle.fillColor : Color(.tertiarySystemBackground))
                        .frame(width: 50, height: 50)
                    
                    if isConfigured {
                        Circle()
                            .stroke(style.nodeStyle.borderColor, lineWidth: 2)
                            .frame(width: 50, height: 50)
                        
                        Text("A")
                            .font(.headline)
                            .foregroundColor(style.nodeStyle.textColor)
                    } else {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(style.name)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
        .disabled(!isConfigured)
        .opacity(isConfigured ? 1.0 : 0.5)
    }
}

// MARK: - 統一スタイル用カラーピッカー行
struct UnifyColorPickerRow: View {
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
                        Button(action: {
                            selectedColor = color
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(isColorEqual(selectedColor, color) ? Color.blue : Color.gray.opacity(0.3), lineWidth: isColorEqual(selectedColor, color) ? 3 : 1)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func isColorEqual(_ c1: Color, _ c2: Color) -> Bool {
        let uiColor1 = UIColor(c1)
        let uiColor2 = UIColor(c2)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
}
