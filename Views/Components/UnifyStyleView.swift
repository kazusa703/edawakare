// Views/Post/Components/UnifyStyleView.swift

import SwiftUI

struct UnifyStyleView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var nodes: [StyledNode]
    @Binding var connections: [StyledConnection]
    let centerNodeText: String
    
    // ノードスタイル（Color を使用）
    @State private var fillColor: Color = .purple
    @State private var borderColor: Color = .pink
    @State private var textColor: Color = .white
    
    // 線スタイル
    @State private var lineColor: Color = .purple
    @State private var lineWidth: CGFloat = 2.0
    
    // プリセットカラー
    let colorOptions: [Color] = [
        .purple, .pink, .blue, .green, .orange, .red, .yellow, .cyan, .mint, .indigo,
        Color(.systemGray), .white, .black
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ノードの色セクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ノードの色")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            // 塗りつぶし
                            UnifyColorPickerRow(
                                title: "塗りつぶし",
                                selectedColor: $fillColor,
                                colors: colorOptions
                            )
                            
                            Divider()
                            
                            // 縁の色
                            UnifyColorPickerRow(
                                title: "縁の色",
                                selectedColor: $borderColor,
                                colors: colorOptions
                            )
                            
                            Divider()
                            
                            // 文字の色
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
                    
                    // 線の色セクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("線のスタイル")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            // 線の色
                            UnifyColorPickerRow(
                                title: "線の色",
                                selectedColor: $lineColor,
                                colors: colorOptions
                            )
                            
                            Divider()
                            
                            // 線の太さ
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
                                
                                // 太さプレビュー
                                HStack {
                                    ForEach([1.0, 2.0, 3.0, 4.0, 5.0, 6.0], id: \.self) { width in
                                        Button(action: {
                                            lineWidth = width
                                        }) {
                                            RoundedRectangle(cornerRadius: width / 2)
                                                .fill(lineColor)
                                                .frame(width: 30, height: width)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: width / 2)
                                                        .stroke(lineWidth == width ? Color.blue : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        if width < 6.0 {
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.top, 8)
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
                            // 線のプレビュー
                            Path { path in
                                path.move(to: CGPoint(x: 100, y: 120))
                                path.addLine(to: CGPoint(x: 250, y: 120))
                            }
                            .stroke(lineColor, lineWidth: lineWidth)
                            
                            // 親ノード
                            Circle()
                                .fill(fillColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(borderColor, lineWidth: 2)
                                )
                                .overlay(
                                    Text("親")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(textColor)
                                )
                                .position(x: 80, y: 120)
                            
                            // 子ノード
                            Circle()
                                .fill(fillColor)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(borderColor, lineWidth: 2)
                                )
                                .overlay(
                                    Text("子")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(textColor)
                                )
                                .position(x: 270, y: 120)
                        }
                        .frame(height: 200)
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
                    .padding(.top, 8)
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("スタイルを統一")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyToAll() {
        // すべてのノードにスタイルを適用
        for index in nodes.indices {
            nodes[index].style = NodeStyleData(
                fillColor: fillColor,
                borderColor: borderColor,
                textColor: textColor
            )
        }
        
        // すべての接続線にスタイルを適用
        for index in connections.indices {
            connections[index].style = ConnectionStyleData(
                lineColor: lineColor,
                lineWidth: lineWidth
            )
        }
        
        dismiss()
    }
}

// MARK: - 統一用カラーピッカー行
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
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
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
    
    // Color の比較用ヘルパー
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
