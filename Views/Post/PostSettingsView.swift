// Views/Post/PostSettingsView.swift

import SwiftUI

struct PostSettingsView: View {
    var onPost: (String, Bool, [String]) -> Void
    var onCancel: () -> Void

    @State private var visibility: PostVisibility = .publicPost
    @State private var commentsEnabled: Bool = true
    @State private var hashtags: [String] = []
    @State private var newHashtag: String = ""

    enum PostVisibility: String, CaseIterable {
        case publicPost = "public"
        case followers = "followers"
        case privatePost = "private"

        var displayName: String {
            switch self {
            case .publicPost: return "全員に公開"
            case .followers: return "フォロワーのみ"
            case .privatePost: return "自分のみ"
            }
        }

        var icon: String {
            switch self {
            case .publicPost: return "globe"
            case .followers: return "person.2.fill"
            case .privatePost: return "lock.fill"
            }
        }

        var description: String {
            switch self {
            case .publicPost: return "すべてのユーザーが閲覧できます"
            case .followers: return "フォロワーのみが閲覧できます"
            case .privatePost: return "自分だけが閲覧できます"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 公開範囲セクション
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.purple)
                            Text("公開範囲")
                                .font(.headline)
                        }

                        VStack(spacing: 8) {
                            ForEach(PostVisibility.allCases, id: \.self) { option in
                                VisibilityOptionRow(
                                    option: option,
                                    isSelected: visibility == option,
                                    onSelect: { visibility = option }
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // コメント設定セクション
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .foregroundColor(.purple)
                            Text("コメント設定")
                                .font(.headline)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("コメントを許可")
                                    .font(.subheadline)
                                Text("オフにするとコメントできなくなります")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $commentsEnabled)
                                .labelsHidden()
                                .tint(.purple)
                        }
                        .padding(.vertical, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // ハッシュタグセクション
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(.purple)
                            Text("ハッシュタグ")
                                .font(.headline)
                        }

                        // 入力フィールド
                        HStack {
                            TextField("タグを入力", text: $newHashtag)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)

                            Button(action: addHashtag) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(newHashtag.isEmpty ? .gray : .purple)
                            }
                            .disabled(newHashtag.isEmpty)
                        }

                        // 追加されたタグの表示
                        if !hashtags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(hashtags, id: \.self) { tag in
                                    HashtagChip(tag: tag, onRemove: {
                                        removeHashtag(tag)
                                    })
                                }
                            }
                        }

                        Text("投稿に関連するキーワードを追加できます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("投稿設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("戻る") {
                        onCancel()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // 投稿ボタン
                VStack {
                    Button(action: submitPost) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("投稿")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground).shadow(radius: 8))
            }
        }
    }

    private func addHashtag() {
        let trimmed = newHashtag.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
        guard !trimmed.isEmpty, !hashtags.contains(trimmed) else { return }

        hashtags.append(trimmed)
        newHashtag = ""
        HapticManager.shared.lightImpact()
    }

    private func removeHashtag(_ tag: String) {
        hashtags.removeAll { $0 == tag }
        HapticManager.shared.lightImpact()
    }

    private func submitPost() {
        HapticManager.shared.success()
        onPost(visibility.rawValue, commentsEnabled, hashtags)
    }
}

// MARK: - 公開範囲オプション行
struct VisibilityOptionRow: View {
    let option: PostSettingsView.PostVisibility
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            onSelect()
        }) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .purple)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.purple : Color(.systemBackground))
            )
        }
    }
}

// MARK: - ハッシュタグチップ
struct HashtagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.subheadline)
                .foregroundColor(.purple)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(16)
    }
}

