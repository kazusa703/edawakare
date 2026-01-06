// Views/Auth/AuthViews.swift

import SwiftUI

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }
}

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showPasswordReset = false
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    AppLogo()
                    Spacer()
                    
                    VStack(spacing: 16) {
                        TextField("メールアドレス", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("パスワード", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.password)
                        
                        HStack {
                            Spacer()
                            Button("パスワードを忘れた？") { showPasswordReset = true }
                                .font(.footnote)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    PrimaryButton(
                        "ログイン",
                        isLoading: authService.isLoading,
                        isDisabled: email.isEmpty || password.isEmpty
                    ) { login() }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    HStack {
                        Text("アカウントをお持ちでない方は")
                            .foregroundColor(.secondary)
                        Button("新規登録") { showSignUp = true }
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .padding(.bottom, 32)
                }
            }
            .navigationDestination(isPresented: $showSignUp) { SignUpView() }
            .sheet(isPresented: $showPasswordReset) { PasswordResetView() }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(authService.errorMessage ?? "エラーが発生しました")
            }
        }
    }
    
    private func login() {
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                showError = true
            }
        }
    }
}

// MARK: - Sign Up View
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
    
    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 8 && password == confirmPassword && username.count >= 3 && !displayName.isEmpty
    }
    
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
                    AuthTextField(label: "メールアドレス", placeholder: "example@email.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    AuthSecureField(label: "パスワード", placeholder: "8文字以上", text: $password)
                    AuthSecureField(label: "パスワード（確認）", placeholder: "もう一度入力", text: $confirmPassword)
                    
                    Divider().padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        AuthTextField(label: "ユーザーID", placeholder: "英数字とアンダースコアのみ", text: $username)
                            .autocapitalization(.none)
                        Text("@\(username.isEmpty ? "username" : username)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    AuthTextField(label: "表示名", placeholder: "ニックネーム", text: $displayName)
                }
                .padding(.horizontal, 24)
                
                PrimaryButton("アカウント作成", isLoading: authService.isLoading, isDisabled: !isFormValid) { signUp() }
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
    
    private func signUp() {
        guard password == confirmPassword else {
            localError = "パスワードが一致しません"
            showError = true
            return
        }
        
        Task {
            do {
                try await authService.signUp(email: email, password: password, username: username, displayName: displayName)
            } catch {
                localError = authService.errorMessage
                showError = true
            }
        }
    }
}

// MARK: - Password Reset View
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
                
                PrimaryButton("リセットリンクを送信", isLoading: authService.isLoading, isDisabled: email.isEmpty) { resetPassword() }
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

// MARK: - App Logo
struct AppLogo: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.primaryGradient)
            Text("枝分かれ")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("興味の繋がりを共有しよう")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Auth Text Field
struct AuthTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(CustomTextFieldStyle())
        }
    }
}

// MARK: - Auth Secure Field
struct AuthSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            SecureField(placeholder, text: $text)
                .textFieldStyle(CustomTextFieldStyle())
        }
    }
}
