// Views/Settings/FavoriteStyleEditorView.swift

import SwiftUI

struct FavoriteStyleEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var styleManager = StyleManager.shared
    
    @State private var selectedSlot: Int? = nil
    @State private var showEditor = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(styleManager.favoriteStyles.enumerated()), id: \.element.id) { index, style in
                        FavoriteStyleRow(
                            style: style,
                            slot: index,
                            isConfigured: styleManager.isSlotConfigured(index),
                            onEdit: {
                                selectedSlot = index
                                showEditor = true
                            }
                        )
                    }
                } header: {
                    Text("お気に入りスタイル")
                } footer: {
                    Text("投稿作成時に「統一スタイル」からワンタッチで適用できます")
                }
            }
            .navigationTitle("プリセット編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                if let slot = selectedSlot {
                    FavoriteStyleDetailEditor(
                        slot: slot,
                        style: styleManager.favoriteStyles[slot]
                    )
                }
            }
        }
    }
}

// MARK: - スタイル行
struct FavoriteStyleRow: View {
    let style: FavoriteStyle
    let slot: Int
    let isConfigured: Bool
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 16) {
                // プレビュー
                ZStack {
                    Circle()
                        .fill(style.nodeStyle.fillColor)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .stroke(style.nodeStyle.borderColor, lineWidth: 2)
                        .frame(width: 44, height: 44)
                    
                    Text("A")
                        .font(.headline)
                        .foregroundColor(style.nodeStyle.textColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isConfigured {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(style.connectionStyle.lineColor)
                                .frame(width: 12, height: 12)
                            
                            Text("線の太さ: \(style.connectionStyle.lineWidth, specifier: "%.1f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("未設定")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - スタイル詳細編集
struct FavoriteStyleDetailEditor: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var styleManager = StyleManager.shared
    
    let slot: Int
    let style: FavoriteStyle
    
    @State private var name: String = ""
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
                    // 名前
                    VStack(alignment: .leading, spacing: 8) {
                        Text("スタイル名")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("スタイル名", text: $name)
                            .font(.body)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                    
                    // ノードの色
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ノードの色")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            StyleColorPickerRow(title: "塗りつぶし", selectedColor: $fillColor, colors: colorOptions)
                            Divider()
                            StyleColorPickerRow(title: "縁の色", selectedColor: $borderColor, colors: colorOptions)
                            Divider()
                            StyleColorPickerRow(title: "文字の色", selectedColor: $textColor, colors: colorOptions)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // 線のスタイル
                    VStack(alignment: .leading, spacing: 16) {
                        Text("線のスタイル")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            StyleColorPickerRow(title: "線の色", selectedColor: $lineColor, colors: colorOptions)
                            
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
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // プレビュー
                    VStack(alignment: .leading, spacing: 16) {
                        Text("プレビュー")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            // 線
                            Path { path in
                                path.move(to: CGPoint(x: 80, y: 80))
                                path.addLine(to: CGPoint(x: 220, y: 80))
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
                                        .font(.caption)
                                        .foregroundColor(textColor)
                                )
                                .position(x: 60, y: 80)
                            
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
                                        .font(.caption)
                                        .foregroundColor(textColor)
                                )
                                .position(x: 240, y: 80)
                        }
                        .frame(height: 140)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("スタイル \(slot + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveStyle()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadStyle()
            }
        }
    }
    
    private func loadStyle() {
        name = style.name
        fillColor = style.nodeStyle.fillColor
        borderColor = style.nodeStyle.borderColor
        textColor = style.nodeStyle.textColor
        lineColor = style.connectionStyle.lineColor
        lineWidth = style.connectionStyle.lineWidth
    }
    
    private func saveStyle() {
        let newStyle = styleManager.createFavoriteStyle(
            name: name,
            fillColor: fillColor,
            borderColor: borderColor,
            textColor: textColor,
            lineColor: lineColor,
            lineWidth: lineWidth
        )
        styleManager.saveToSlot(slot, style: FavoriteStyle(
            id: style.id,
            name: name,
            nodeStyle: newStyle.nodeStyle,
            connectionStyle: newStyle.connectionStyle
        ))
    }
}

// MARK: - カラーピッカー行
struct StyleColorPickerRow: View {
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
                                        .stroke(isSelected(color) ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected(color) ? 3 : 1)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func isSelected(_ color: Color) -> Bool {
        let c1 = UIColor(selectedColor)
        let c2 = UIColor(color)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
}
