import SwiftUI

struct ReminderPopupView: View {
    let goalTitle: String
    let countdownText: String?
    let overlayOpacity: Double
    let onSelect: (GoalProgressStatus) -> Void

    var body: some View {
        ZStack {
            Color(hex: "FAE6D7")
                .opacity(clampedOverlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("目标提醒")
                    .font(.arial(size: 40, weight: .bold))
                    .foregroundStyle(Color(hex: "1F1F1F"))

                Text("你现在在实现这个目标吗？")
                    .font(.arial(size: 28, weight: .semibold))
                    .foregroundStyle(Color(hex: "1F1F1F"))

                Text(goalTitle)
                    .font(.arial(size: 30, weight: .bold))
                    .foregroundStyle(Color(hex: "1F1F1F"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if let countdownText, !countdownText.isEmpty {
                    Text(countdownText)
                        .font(.arial(size: 20, weight: .semibold))
                        .foregroundStyle(Color(hex: "579FCA"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Text("快捷键: 1 / 2 / 3")
                    .font(.arial(size: 16))
                    .foregroundStyle(Color(hex: "666666"))

                HStack(spacing: 16) {
                    popupButton(for: .completed, color: Color(hex: "579FCA"))
                    popupButton(for: .inProgress, color: Color(hex: "B4DDF4"))
                    popupButton(for: .startNow, color: Color(hex: "F7DC7C"))
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 1200)
            .padding(40)
            .background(Color.white.opacity(cardOpacity))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: "E7D8CC"), lineWidth: 1)
            }
            .padding(40)
        }
    }

    private var clampedOverlayOpacity: Double {
        min(max(overlayOpacity, 0.15), 1.0)
    }

    private var cardOpacity: Double {
        max(0.82, min(0.96, clampedOverlayOpacity + 0.10))
    }

    private func popupButton(for status: GoalProgressStatus, color: Color) -> some View {
        Button(status.buttonTitle) {
            onSelect(status)
        }
        .buttonStyle(.plain)
        .font(.arial(size: 24, weight: .bold))
        .foregroundStyle(Color(hex: "1F1F1F"))
        .frame(width: 260, height: 92)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
