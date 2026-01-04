// Views/Auth/PasswordResetView.swift

import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)
                    Text("パスワードをリセット")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("登録したメールアドレスを入力してください。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                TextField("メールアドレス", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal, 24)
                
                Button(action: resetPassword) {
                    HStack {
                        if authService.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("リセットリンクを送信").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(LinearGradient(colors: email.isEmpty ? [.gray] : [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(email.isEmpty || authService.isLoading)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("送信完了", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("パスワードリセット用のメールを送信しました。")
            }
        }
    }
    
    private func resetPassword() {
        Task {
            try? await authService.resetPassword(email: email)
            showSuccess = true
        }
    }
}
