// Views/Components/SharedComponents.swift

import SwiftUI

// MARK: - 備考表示ポップアップ
struct NoteDisplayPopup: View {
    let nodeName: String
    let note: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.orange)
                    Text(nodeName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                Text(note)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }
}
