// Views/Post/Components/ConnectionStyleEditor.swift

import SwiftUI

struct ConnectionStyleEditor: View {
    @Binding var connection: StyledConnection
    @Environment(\.dismiss) var dismiss
    
    @State private var tempReason: String = ""
    @State private var tempLineColor: Color = .purple
    @State private var tempLineWidth: CGFloat = 2
    
    var body: some View {
        NavigationStack {
            Form {
                // 理由編集
                Section("接続の理由") {
                    TextField("なぜつながる？（任意）", text: $tempReason)
                }
                
                // 線のスタイル
                Section("線のスタイル") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("線の色")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(PresetColors.lineColors, id: \.self) { presetColor in
                                    Circle()
                                        .fill(presetColor)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(tempLineColor == presetColor ? Color.blue : Color.gray.opacity(0.3), lineWidth: tempLineColor == presetColor ? 3 : 1)
                                        )
                                        .onTapGesture {
                                            tempLineColor = presetColor
                                        }
                                }
                                
                                ColorPicker("", selection: $tempLineColor)
                                    .labelsHidden()
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("線の太さ")
                            Spacer()
                            Text("\(Int(tempLineWidth))pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $tempLineWidth, in: 1...8, step: 1)
                    }
                }
                
                // プレビュー
                Section("プレビュー") {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 40, height: 40)
                            
                            Rectangle()
                                .fill(tempLineColor)
                                .frame(width: tempLineWidth, height: 40)
                            
                            Circle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 40, height: 40)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("接続線編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
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
                tempReason = connection.reason
                tempLineColor = connection.style.lineColor.color
                tempLineWidth = connection.style.lineWidth
            }
        }
    }
    
    private func saveChanges() {
        connection.reason = tempReason
        connection.style.lineColor = CodableColor(color: tempLineColor)
        connection.style.lineWidth = tempLineWidth
    }
}
