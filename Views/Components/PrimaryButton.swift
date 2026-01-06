// Views/Components/PrimaryButton.swift

import SwiftUI

// MARK: - プライマリーボタン（グラデーション）
struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isDisabled ? AppColors.disabledGradient : AppColors.horizontalGradient)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - セカンダリーボタン
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
        }
    }
}

// MARK: - 線幅スライダー
struct LineWidthSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let presets: [CGFloat]
    
    init(value: Binding<CGFloat>, range: ClosedRange<CGFloat> = 1...6, presets: [CGFloat] = [1, 2, 3, 4, 5, 6]) {
        self._value = value
        self.range = range
        self.presets = presets
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("線の太さ")
                    .font(.subheadline)
                Spacer()
                Text("\(value, specifier: "%.1f")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range, step: 0.5)
                .tint(.purple)
            
            HStack {
                ForEach(presets, id: \.self) { width in
                    Button(action: { value = width }) {
                        Text("\(Int(width))")
                            .font(.caption)
                            .fontWeight(value == width ? .bold : .regular)
                            .foregroundColor(value == width ? .white : .primary)
                            .frame(width: 36, height: 28)
                            .background(value == width ? Color.purple : Color(.tertiarySystemBackground))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}
