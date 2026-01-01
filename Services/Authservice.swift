// Services/AuthService.swift
// 認証サービス（セッション永続化対応）

import Foundation
import Combine
import Supabase

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true  // 起動時はtrue
    @Published var errorMessage: String?
    
    private var authStateTask: Task<Void, Never>?
    
    init() {
        Task {
            await checkExistingSession()
            setupAuthStateListener()
        }
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - 既存セッションの確認（起動時）
    private func checkExistingSession() async {
        do {
            // 保存されているセッションを取得
            let session = try await SupabaseClient.shared.client.auth.session
            
            // セッションが期限切れでないか確認
            if session.isExpired {
                // 期限切れの場合はリフレッシュを試みる
                let refreshedSession = try await SupabaseClient.shared.client.auth.refreshSession()
                await fetchCurrentUser(userId: refreshedSession.user.id)
            } else {
                await fetchCurrentUser(userId: session.user.id)
            }
            
            isAuthenticated = true
            isLoading = false
            
        } catch {
            // セッションがない、または無効な場合
            print("No existing session: \(error)")
            isAuthenticated = false
            isLoading = false
        }
    }
    
    // MARK: - 認証状態の監視
    private func setupAuthStateListener() {
        authStateTask = Task { [weak self] in
            for await (event, session) in SupabaseClient.shared.client.auth.authStateChanges {
                await MainActor.run {
                    switch event {
                    case .signedIn:
                        if let session = session, !session.isExpired {
                            self?.isAuthenticated = true
                            Task {
                                await self?.fetchCurrentUser(userId: session.user.id)
                            }
                        }
                    case .signedOut:
                        self?.currentUser = nil
                        self?.isAuthenticated = false
                    case .tokenRefreshed:
                        print("Token refreshed successfully")
                    default:
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - ユーザー情報取得
    private func fetchCurrentUser(userId: UUID) async {
        do {
            let user: User = try await SupabaseClient.shared.client
                .from("users")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            currentUser = user
        } catch {
            print("Error fetching user: \(error)")
        }
    }
    
   
    // MARK: - 新規登録
    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // メタデータにusernameとdisplay_nameを含めて登録
            let authResponse = try await SupabaseClient.shared.client.auth.signUp(
                email: email,
                password: password,
                data: [
                    "username": .string(username),
                    "display_name": .string(displayName)
                ]
            )
            
            let userId = authResponse.user.id
            
            // 少し待ってからユーザー情報を取得（トリガーが実行されるのを待つ）
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            await fetchCurrentUser(userId: userId)
            isAuthenticated = true
            isLoading = false
            
        } catch {
            isLoading = false
            
            let errorString = error.localizedDescription.lowercased()
            
            if errorString.contains("already") || errorString.contains("exists") {
                errorMessage = "このメールアドレスは既に登録されています"
            } else if errorString.contains("weak") || errorString.contains("password") {
                errorMessage = "パスワードは6文字以上で入力してください"
            } else if errorString.contains("email") && errorString.contains("invalid") {
                errorMessage = "メールアドレスの形式が正しくありません"
            } else {
                errorMessage = "登録に失敗しました"
            }
            
            throw error
        }
    }
    
    // MARK: - ログイン
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await SupabaseClient.shared.client.auth.signIn(
                email: email,
                password: password
            )
            
            await fetchCurrentUser(userId: session.user.id)
            isAuthenticated = true
            isLoading = false
            
        } catch {
            isLoading = false
            
            let errorString = error.localizedDescription.lowercased()
            
            if errorString.contains("invalid") || errorString.contains("credentials") {
                errorMessage = "メールアドレスまたはパスワードが正しくありません"
            } else if errorString.contains("not found") {
                errorMessage = "このメールアドレスは登録されていません"
            } else {
                errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
            }
            
            throw error
        }
    }
    
    // MARK: - ログアウト
    func signOut() async throws {
        do {
            try await SupabaseClient.shared.client.auth.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - パスワードリセット
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseClient.shared.client.auth.resetPasswordForEmail(email)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - プロフィール更新
    func updateProfile(displayName: String, username: String, bio: String?) async throws {
        guard let userId = currentUser?.id else { return }
        
        do {
            let update = ProfileUpdateAuth(
                display_name: displayName,
                username: username,
                bio: bio
            )
            
            try await SupabaseClient.shared.client
                .from("users")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()
            
            currentUser?.displayName = displayName
            currentUser?.username = username
            currentUser?.bio = bio
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - アカウント削除
    func deleteAccount() async throws {
        guard let userId = currentUser?.id else { return }
        
        do {
            try await SupabaseClient.shared.client
                .from("users")
                .delete()
                .eq("id", value: userId.uuidString)
                .execute()
            
            try await signOut()
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - Insert/Update用の構造体
struct UserInsert: Encodable {
    let id: String
    let email: String
    let username: String
    let display_name: String
}

struct ProfileUpdateAuth: Encodable {
    let display_name: String
    let username: String
    let bio: String?
}
