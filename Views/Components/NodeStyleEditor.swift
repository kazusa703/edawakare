// Views/Post/Components/NodeStyleEditor.swift

import SwiftUI

struct NodeStyleEditor: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var node: StyledNode
    @Binding var centerNodeText: String
    var connection: Binding<StyledConnection>?
    
    @State private var editingName: String = ""
    @State private var editingDetail: String = ""
    @State private var fillColor: Color = .purple
    @State private var borderColor: Color = .purple
    @State private var textColor: Color = .white
    
    @State private var lineColor: Color = .purple
    @State private var lineWidth: CGFloat = 2.0
    @State private var connectionReason: String = ""
    
    private let detailMaxLength = 200
    
    let colorOptions: [Color] = [
        .purple, .pink, .blue, .green, .orange, .red, .yellow, .cyan, .mint, .indigo,
        Color(.systemGray), .white, .black
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ノード名セクション
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ノード名")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("ノード名", text: $editingName)
                            .font(.body)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                    
                    // 線の設定セクション
                    if connection != nil {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("線の設定")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("なぜつながる？")
                                        .font(.subheadline)
                                    
                                    TextField("理由（任意）", text: $connectionReason)
                                        .font(.body)
                                        .padding()
                                        .background(Color(.tertiarySystemBackground))
                                        .cornerRadius(8)
                                }
                                
                                Divider()
                                
                                EditorColorPickerRow(
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
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                    }
                    
                    // ノードの色セクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ノードの色")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            EditorColorPickerRow(
                                title: "塗りつぶし",
                                selectedColor: $fillColor,
                                colors: colorOptions
                            )
                            
                            Divider()
                            
                            EditorColorPickerRow(
                                title: "縁の色",
                                selectedColor: $borderColor,
                                colors: colorOptions
                            )
                            
                            Divider()
                            
                            EditorColorPickerRow(
                                title: "文字の色",
                                selectedColor: $textColor,
                                colors: colorOptions
                            )
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // ノードの詳細セクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ノードの詳細")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $editingDetail)
                                .font(.body)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(8)
                                .onChange(of: editingDetail) { _, newValue in
                                    if newValue.count > detailMaxLength {
                                        editingDetail = String(newValue.prefix(detailMaxLength))
                                    }
                                }
                            
                            HStack {
                                Text("閲覧者がノードを長押しすると表示されます")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(editingDetail.count)/\(detailMaxLength)")
                                    .font(.caption)
                                    .foregroundColor(editingDetail.count >= detailMaxLength ? .red : .secondary)
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
                            if connection != nil {
                                Path { path in
                                    path.move(to: CGPoint(x: 80, y: 100))
                                    path.addLine(to: CGPoint(x: 200, y: 100))
                                }
                                .stroke(lineColor, lineWidth: lineWidth)
                                
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .position(x: 60, y: 100)
                            }
                            
                            Circle()
                                .fill(fillColor)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(borderColor, lineWidth: 2)
                                )
                                .overlay(
                                    Text(editingName.isEmpty ? "テキスト" : editingName)
                                        .font(.system(size: 12))
                                        .foregroundColor(textColor)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .padding(8)
                                )
                                .position(x: connection != nil ? 220 : 150, y: 100)
                            
                            // 詳細ありバッジ
                            if !editingDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 20, height: 20)
                                    
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                }
                                .position(x: connection != nil ? 250 : 180, y: 70)
                            }
                        }
                        .frame(height: 160)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("ノード編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }
    
    private func loadCurrentValues() {
        editingName = node.isCenter ? centerNodeText : node.text
        editingDetail = node.detail
        fillColor = node.style.fillColor.color
        borderColor = node.style.borderColor.color
        textColor = node.style.textColor.color
        
        if let conn = connection?.wrappedValue {
            lineColor = conn.style.lineColor.color
            lineWidth = conn.style.lineWidth
            connectionReason = conn.reason
        }
    }
    
    private func saveChanges() {
        if node.isCenter {
            centerNodeText = editingName
        } else {
            node.text = editingName
        }
        
        node.detail = editingDetail
        
        node.style = NodeStyleData(
            fillColor: fillColor,
            borderColor: borderColor,
            textColor: textColor
        )
        
        if var conn = connection?.wrappedValue {
            conn.reason = connectionReason
            conn.style = ConnectionStyleData(
                lineColor: lineColor,
                lineWidth: lineWidth
            )
            connection?.wrappedValue = conn
        }
    }
}

// MARK: - エディター用カラーピッカー行
struct EditorColorPickerRow: View {
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
