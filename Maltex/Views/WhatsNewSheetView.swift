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
                    Text("欢迎使用 Maltex 1.2.1")
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
                    icon: "sidebar.right",
                    color: .accentColor,
                    title: "原生侧边检查器",
                    description: "任务详情全新升级为原生 Inspector 面板，自动自适应宽度，不再遮挡任务列表。"
                )

                WhatsNewFeatureRow(
                    icon: "link.badge.plus",
                    color: .blue,
                    title: "磁力链接下载确认",
                    description: "磁力链接拉取元数据后自动弹出确认弹窗，支持文件挑选与自定义下载路径。"
                )

                WhatsNewFeatureRow(
                    icon: "arrow.clockwise.circle",
                    color: .green,
                    title: "重复下载智能处理",
                    description: "智能识别已存在的磁链任务，友好提醒并支持一键清理旧任务重新下载。"
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
