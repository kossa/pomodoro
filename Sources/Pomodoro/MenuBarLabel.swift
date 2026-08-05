import AppKit
import SwiftUI

/// The menu bar item's label.
///
/// SwiftUI draws a `Text` label as a template, so `foregroundStyle` on it is
/// ignored and the title always comes out in the menu bar's own colour. To honour
/// a chosen colour the title is drawn into a non-template image instead. The plain
/// `Text` is kept for the default, so an uncoloured item still adapts to light and
/// dark menu bars on its own.
struct MenuBarLabel: View {
    let title: String
    let color: Color?

    var body: some View {
        if let color, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            Image(nsImage: MenuBarTitleImage.make(title, color: NSColor(color)))
        } else {
            Text(title).monospacedDigit()
        }
    }
}

enum MenuBarTitleImage {
    /// Drawn through `NSImage(size:flipped:drawingHandler:)` so the title is
    /// re-rendered per display scale and stays sharp on Retina.
    static func make(_ title: String, color: NSColor) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attributed = NSAttributedString(string: title, attributes: attributes)
        let size = attributed.size()
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)),
                            flipped: false) { rect in
            attributed.draw(in: rect)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = title
        return image
    }

    /// The menu bar's own font, with monospaced digits so a changing countdown
    /// doesn't force the item to resize every second.
    private static let font: NSFont = {
        let base = NSFont.menuBarFont(ofSize: 0)
        return NSFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: .regular)
    }()
}
