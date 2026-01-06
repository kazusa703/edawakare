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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    favoriteStylesSection
                    nodeColorSection
                    lineStyleSection
                    previewSection
                    applyButton
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("統一スタイル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var favoriteStylesSection: some View {
        EditorSection(title: "お気に入りスタイル") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(Array(styleManager.favoriteStyles.enumerated()), id: \.element.id) { index, style in
                        FavoriteStyleButton(
                            style: style,
                            isConfigured: styleManager.isSlotConfigured(index),
                            onTap: { applyFavoriteStyle(style) }
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
        }
    }
    
    private var nodeColorSection: some View {
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
    }
    
    private var lineStyleSection: some View {
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
    }
    
    private var previewSection: some View {
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
    
    private var applyButton: some View {
        PrimaryButton("すべてに適用") { applyToAll() }
    }
    
    // MARK: - Methods
    
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
            nodes[index].style = NodeStyleData(fillColor: fillColor, borderColor: borderColor, textColor: textColor)
        }
        for index in connections.indices {
            connections[index].style = ConnectionStyleData(lineColor: lineColor, lineWidth: lineWidth)
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

// MARK: - スタイルプレビューキャンバス
struct StylePreviewCanvas: View {
    let fillColor: Color
    let borderColor: Color
    let textColor: Color
    let lineColor: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 100, y: 80))
                path.addLine(to: CGPoint(x: 200, y: 80))
            }
            .stroke(lineColor, lineWidth: lineWidth)
            
            nodeCircle(text: "親", size: 70, position: CGPoint(x: 80, y: 80))
            nodeCircle(text: "子", size: 60, position: CGPoint(x: 220, y: 80))
        }
    }
    
    private func nodeCircle(text: String, size: CGFloat, position: CGPoint) -> some View {
        Circle()
            .fill(fillColor)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(borderColor, lineWidth: 2))
            .overlay(
                Text(text)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textColor)
            )
            .position(position)
    }
}
