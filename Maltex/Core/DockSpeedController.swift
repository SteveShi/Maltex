import AppKit

/// 在 Dock 图标底部叠加实时下载速度。
@MainActor
final class DockSpeedController {
    private let dockTile = NSApp.dockTile
    private let iconView = DockSpeedIconView()
    private var isEnabled = false

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        if enabled {
            dockTile.contentView = iconView
        } else {
            iconView.downloadSpeed = 0
            dockTile.contentView = nil
        }
        dockTile.display()
    }

    func update(downloadSpeed: Int64) {
        guard isEnabled else { return }
        let clamped = max(0, downloadSpeed)
        guard clamped != iconView.downloadSpeed else { return }
        iconView.downloadSpeed = clamped
        dockTile.display()
    }
}

/// 绘制应用图标，并在有下载速度时叠加速度条。
private final class DockSpeedIconView: NSView {
    var downloadSpeed: Int64 = 0

    override func draw(_ dirtyRect: NSRect) {
        NSApp.applicationIconImage?.draw(
            in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)

        guard downloadSpeed > 0 else { return }

        let text = "\(ByteCountFormatterUtil.string(fromByteCount: downloadSpeed))/s"

        let bannerHeight = bounds.height * 0.26
        let horizontalInset = bounds.width * 0.05
        let bannerRect = NSRect(
            x: horizontalInset,
            y: bounds.height * 0.04,
            width: bounds.width - horizontalInset * 2,
            height: bannerHeight)

        let bannerPath = NSBezierPath(
            roundedRect: bannerRect,
            xRadius: bannerHeight * 0.3,
            yRadius: bannerHeight * 0.3)
        NSColor.black.withAlphaComponent(0.72).setFill()
        bannerPath.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let availableWidth = bannerRect.width - bannerHeight * 0.4
        var fontSize = bannerHeight * 0.56
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ]

        // 速度文本宽度不固定，按可用宽度收缩字号以避免裁切。
        while fontSize > 6,
            (text as NSString).size(withAttributes: attributes).width > availableWidth
        {
            fontSize -= 1
            attributes[.font] = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        }

        let textSize = (text as NSString).size(withAttributes: attributes)
        let textRect = NSRect(
            x: bannerRect.minX,
            y: bannerRect.midY - textSize.height / 2,
            width: bannerRect.width,
            height: textSize.height)
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
}
