// Views/Collaboration/CreateCollaborationView.swift

import SwiftUI

struct CreateCollaborationView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var mutualFollowers: [User] = []
    @State private var selectedUsers: Set<UUID> = []
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let maxInvites = 3

    private var userTheme: ThemeColor {
        ThemeColor.from(string: authService.currentUser?.themeColor)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 説明
                    headerSection

                    Divider()

                    // 相互フォローリスト
                    if isLoading {
                        loadingView
                    } else if mutualFollowers.isEmpty {
                        emptyView
                    } else {
                        mutualFollowersList
                    }

                    Divider()

                    // 作成ボタン
                    createButton
                }
            }
            .navigationTitle("共同作業を始める")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadMutualFollowers()
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - ヘッダーセクション
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(userTheme.gradient)

            Text("相互フォロー中のユーザーを招待")
                .font(.headline)

            Text("最大\(maxInvites)人まで招待できます")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 選択数表示
            HStack {
                Text("選択中: \(selectedUsers.count)/\(maxInvites)人")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedUsers.count > 0 ? userTheme.gradientColors.first : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(selectedUsers.count > 0 ? userTheme.gradientColors.first?.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(20)
        }
        .padding()
    }

    // MARK: - ローディング
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("相互フォローを読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 16)
            Spacer()
        }
    }

    // MARK: - 空の状態
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("相互フォロー中のユーザーがいません")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("共同作業を始めるには、\nまず誰かと相互フォローになる必要があります")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - 相互フォローリスト
    private var mutualFollowersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(mutualFollowers) { user in
                    MutualFollowerRow(
                        user: user,
                        isSelected: selectedUsers.contains(user.id),
                        isDisabled: selectedUsers.count >= maxInvites && !selectedUsers.contains(user.id),
                        themeColor: userTheme
                    ) {
                        toggleSelection(user.id)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 作成ボタン
    private var createButton: some View {
        Button(action: createCollaboration) {
            HStack {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("招待を送信")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                selectedUsers.isEmpty ? Color.gray : userTheme.gradient
            )
            .cornerRadius(12)
        }
        .disabled(selectedUsers.isEmpty || isCreating)
        .padding()
    }

    // MARK: - 選択トグル
    private func toggleSelection(_ userId: UUID) {
        HapticManager.shared.lightImpact()

        if selectedUsers.contains(userId) {
            selectedUsers.remove(userId)
        } else if selectedUsers.count < maxInvites {
            selectedUsers.insert(userId)
        }
    }

    // MARK: - 相互フォロー読み込み
    private func loadMutualFollowers() async {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            mutualFollowers = try await CollaborationService.shared.fetchMutualFollowers(userId: userId)
        } catch {
            print("🔴 [CreateCollaboration] 相互フォロー取得エラー: \(error)")
        }

        isLoading = false
    }

    // MARK: - 共同作業作成
    private func createCollaboration() {
        guard let userId = authService.currentUser?.id else { return }
        guard !selectedUsers.isEmpty else { return }

        isCreating = true

        Task {
            do {
                let inviteeIds = Array(selectedUsers)
                _ = try await CollaborationService.shared.createCollaboration(
                    inviterId: userId,
                    inviteeIds: inviteeIds
                )

                await MainActor.run {
                    HapticManager.shared.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - 相互フォロー行
struct MutualFollowerRow: View {
    let user: User
    let isSelected: Bool
    let isDisabled: Bool
    let themeColor: ThemeColor
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // アバター
                UserAvatarView(
                    user: user,
                    size: 50,
                    showMutualBorder: true,
                    currentUserId: nil
                )

                // ユーザー情報
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 選択状態
                ZStack {
                    Circle()
                        .stroke(isSelected ? themeColor.gradientColors.first ?? .purple : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .fill(themeColor.gradient)
                            .frame(width: 20, height: 20)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(12)
            .background(isSelected ? themeColor.gradientColors.first?.opacity(0.1) : AppColors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? themeColor.gradientColors.first ?? .purple : Color.clear, lineWidth: 2)
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled)
        .buttonStyle(PlainButtonStyle())
    }
}
