// Views/Auth/SignUpView.swift

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var showError = false
    @State private var localError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("新規登録")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("アカウントを作成して始めましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("メールアドレス").font(.caption).foregroundColor(.secondary)
                        TextField("example@email.com", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("パスワード").font(.caption).foregroundColor(.secondary)
                        SecureField("8文字以上", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("パスワード（確認）").font(.caption).foregroundColor(.secondary)
                        SecureField("もう一度入力", text: $confirmPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ユーザーID").font(.caption).foregroundColor(.secondary)
                        TextField("英数字とアンダースコアのみ", text: $username)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                        Text("@\(username.isEmpty ? "username" : username)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("表示名").font(.caption).foregroundColor(.secondary)
                        TextField("ニックネーム", text: $displayName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                }
                .padding(.horizontal, 24)
                
                Button(action: signUp) {
                    HStack {
                        if authService.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("アカウント作成").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(LinearGradient(colors: isFormValid ? [.purple, .pink] : [.gray], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid || authService.isLoading)
                .padding(.horizontal, 24)
                
                Text("アカウントを作成することで、利用規約とプライバシーポリシーに同意したことになります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("エラー", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(localError ?? authService.errorMessage ?? "エラーが発生しました")
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 8 && password == confirmPassword && username.count >= 3 && !displayName.isEmpty
    }
    
    private func signUp() {
        guard password == confirmPassword else {
            localError = "パスワードが一致しません"
            showError = true
            return
        }
        
        Task {
            do {
                try await authService.signUp(email: email, password: password, username: username, displayName: displayName)
                // 成功したら自動的にホーム画面へ（authService.isAuthenticated = true になる）
            } catch {
                // エラーを表示
                localError = authService.errorMessage
                showError = true
            }
        }
    }
    }
