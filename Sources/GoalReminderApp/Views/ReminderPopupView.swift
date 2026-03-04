import SwiftUI

struct ReminderPopupView: View {
    let goalTitle: String
    let countdownText: String?
    let overlayOpacity: Double
    @ObservedObject var popupState: ReminderPopupState
    let onSelect: (GoalProgressStatus, String?) -> Void

    @State private var startNowInput = ""
    @FocusState private var startNowInputFocused: Bool

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

            if popupState.isPromptingStartNow {
                startNowInputPrompt
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: popupState.isPromptingStartNow)
        .onChange(of: popupState.promptSequence) { _ in
            startNowInput = ""
            DispatchQueue.main.async {
                startNowInputFocused = true
            }
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
            if status == .startNow {
                popupState.openStartNowPrompt()
            } else {
                onSelect(status, nil)
            }
        }
        .buttonStyle(.plain)
        .font(.arial(size: 24, weight: .bold))
        .foregroundStyle(Color(hex: "1F1F1F"))
        .frame(width: 260, height: 92)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var startNowInputPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("马上去完成前，先写下你现在在干什么")
                .font(.arial(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "1F1F1F"))

            Text("输入后按回车即可记录。直接回车则只记录“马上去完成”，不会保存这条输入。")
                .font(.arial(size: 13))
                .foregroundStyle(Color(hex: "666666"))

            TextField("例如：回微信 / 看邮件 / 刷网页 / 改图例", text: $startNowInput)
                .textFieldStyle(.roundedBorder)
                .font(.arial(size: 15))
                .focused($startNowInputFocused)
                .onSubmit {
                    submitStartNowInput()
                }

            HStack(spacing: 10) {
                Button("返回") {
                    popupState.closeStartNowPrompt()
                }
                .buttonStyle(.plain)
                .font(.arial(size: 13, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(hex: "F3C7BF"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Spacer()

                Button("记录并继续") {
                    submitStartNowInput()
                }
                .buttonStyle(.plain)
                .font(.arial(size: 13, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(hex: "F7DC7C"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(24)
        .frame(maxWidth: 620)
        .background(Color.white.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "E7D8CC"), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 40)
    }

    private func submitStartNowInput() {
        let trimmedInput = startNowInput.trimmingCharacters(in: .whitespacesAndNewlines)
        popupState.closeStartNowPrompt()
        onSelect(.startNow, trimmedInput.isEmpty ? nil : trimmedInput)
    }
}
