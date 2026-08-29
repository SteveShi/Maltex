import SwiftUI
import AppKit

struct WhatsNewSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 4) {
                    Text("欢迎使用 Maltex 1.2.0")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("探索全新优化与核心改进")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            // Features List
            VStack(spacing: 18) {
                WhatsNewFeatureRow(
                    icon: "macwindow.on.rectangle",
                    color: .accentColor,
                    title: "单实例窗口体验",
                    description: "优化外部事件路由机制，彻底修复点击磁力链接或浏览器扩展唤起时重复弹出多窗口的问题。"
                )

                WhatsNewFeatureRow(
                    icon: "circle.inset.filled",
                    color: .green,
                    title: "全新状态指示器",
                    description: "重构侧边栏底部状态呈现，采用极简圆点与状态文案，告别空间拥挤与文字折行。"
                )

                WhatsNewFeatureRow(
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    color: .orange,
                    title: "内核快速自愈",
                    description: "当引擎遇到异常中断或连接错误时，支持直接在状态栏一键重启引擎与重连。"
                )
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)

            // Footer Button
            Button {
                dismiss()
            } label: {
                Text("开始使用")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 440, height: 460)
    }
}

private struct WhatsNewFeatureRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .alignmentGuide(.top) { _ in 0 }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
