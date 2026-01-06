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
                    Text("投稿作成時に「統一スタイル」からワンタップで適用できます")
                }
            }
            .navigationTitle("プリセット編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditor) {
                if let slot = selectedSlot {
                    FavoriteStyleDetailEditor(slot: slot, style: styleManager.favoriteStyles[slot])
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    EditorSection(title: "スタイル名") {
                        TextField("スタイル名", text: $name)
                            .font(.body)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                    
                    EditorSection(title: "ノードの色") {
                        VStack(spacing: 16) {
                            SharedColorPickerRow(title: "塗りつぶし", selectedColor: $fillColor, colors: AppColors.pickerColors)
                            Divider()
                            SharedColorPickerRow(title: "縁の色", selectedColor: $borderColor, colors: AppColors.pickerColors)
                            Divider()
                            SharedColorPickerRow(title: "文字の色", selectedColor: $textColor, colors: AppColors.pickerColors)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    EditorSection(title: "線のスタイル") {
                        VStack(spacing: 16) {
                            SharedColorPickerRow(title: "線の色", selectedColor: $lineColor, colors: AppColors.pickerColors)
                            Divider()
                            LineWidthSlider(value: $lineWidth)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    EditorSection(title: "プレビュー") {
                        StylePreviewCanvas(
                            fillColor: fillColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            lineColor: lineColor,
                            lineWidth: lineWidth
                        )
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
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveStyle()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { loadStyle() }
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
        let newStyle = FavoriteStyle(
            id: style.id,
            name: name,
            nodeStyle: SavedNodeStyle(fillColor: fillColor, borderColor: borderColor, textColor: textColor),
            connectionStyle: SavedConnectionStyle(lineColor: lineColor, lineWidth: lineWidth)
        )
        styleManager.saveToSlot(slot, style: newStyle)
    }
}
