import SwiftUI

/// 1行固定・省略記号なしで右端をクリップするラベル（純 SwiftUI）。
struct ClippingSingleLineText: View {
    var text: String
    var font: Font
    var color: Color

    init(text: String, font: Font = .caption2, color: Color = .primary) {
        self.text = text
        self.font = font
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .hidden()
            .overlay(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
    }
}
