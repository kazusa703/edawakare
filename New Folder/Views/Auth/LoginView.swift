// Views/Auth/LoginView.swift

import SwiftUI

// MARK: - Custom Text Field Style (defined here only)
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }
}

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
                    
                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 60))
                            .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("枝分かれ")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("興味の繋がりを共有しよう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Form
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
                    
                    // Login Button
                    Button(action: login) {
                        HStack {
                            if authService.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("ログイン").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Sign Up Link
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
        print("🟡 ログインボタンが押された")
        print("🟡 email: \(email)")
        print("🟡 password: \(password.isEmpty ? "空" : "入力あり")")
        
        Task {
            do {
                print("🟡 signIn開始...")
                try await authService.signIn(email: email, password: password)
                print("✅ signIn完了")
                print("✅ isAuthenticated: \(authService.isAuthenticated)")
            } catch {
                print("🔴 エラー: \(error)")
                print("🔴 errorMessage: \(authService.errorMessage ?? "nil")")
                showError = true
            }
        }
    }
    }
