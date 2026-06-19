import AppKit
import PaperTodoCore

enum MarkdownStyler {
    static func attributedString(
        from text: String,
        mode: String,
        baseFontSize: CGFloat,
        palette: PaperPalette
    ) -> NSMutableAttributedString {
        let baseFont = NSFont.systemFont(ofSize: baseFontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3

        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: palette.text,
                .paragraphStyle: paragraph
            ]
        )

        guard mode != MarkdownRenderMode.off.rawValue, !text.isEmpty else {
            return attributed
        }

        applyCodeBlockStyles(to: attributed, text: text, baseFontSize: baseFontSize, palette: palette, enhanced: mode == MarkdownRenderMode.enhanced.rawValue)
        applyBlockStyles(to: attributed, text: text, baseFontSize: baseFontSize, palette: palette, enhanced: mode == MarkdownRenderMode.enhanced.rawValue)
        applyInlineStyles(
            to: attributed,
            text: text,
            baseFontSize: baseFontSize,
            palette: palette,
            enhanced: mode == MarkdownRenderMode.enhanced.rawValue
        )
        return attributed
    }

    private static func applyCodeBlockStyles(
        to attributed: NSMutableAttributedString,
        text: String,
        baseFontSize: CGFloat,
        palette: PaperPalette,
        enhanced: Bool
    ) {
        let nsText = text as NSString
        var isInCodeBlock = false
        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                attributed.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: baseFontSize * 0.9, weight: .medium),
                    .foregroundColor: enhanced ? palette.weakText : palette.active,
                    .backgroundColor: palette.hover.withAlphaComponent(0.35)
                ], range: lineRange)
                isInCodeBlock.toggle()
                return
            }

            if isInCodeBlock {
                attributed.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: baseFontSize * 0.95, weight: .regular),
                    .foregroundColor: palette.text,
                    .backgroundColor: palette.hover.withAlphaComponent(0.35)
                ], range: lineRange)
            }
        }
    }

    private static func applyBlockStyles(
        to attributed: NSMutableAttributedString,
        text: String,
        baseFontSize: CGFloat,
        palette: PaperPalette,
        enhanced: Bool
    ) {
        let nsText = text as NSString
        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }

            if let heading = headingLevel(in: trimmed) {
                let size = max(baseFontSize + CGFloat(7 - min(heading, 6)), baseFontSize + 1)
                attributed.addAttributes([
                    .font: NSFont.systemFont(ofSize: size, weight: .semibold),
                    .foregroundColor: palette.text
                ], range: lineRange)
                if enhanced {
                    let markerRange = markerRange(prefix: "#", in: line, lineRange: lineRange)
                    attributed.addAttribute(.foregroundColor, value: palette.weakText, range: markerRange)
                }
                return
            }

            if trimmed.hasPrefix(">") {
                let style = NSMutableParagraphStyle()
                style.headIndent = 12
                style.firstLineHeadIndent = 12
                style.lineSpacing = 3
                attributed.addAttributes([
                    .foregroundColor: palette.weakText,
                    .paragraphStyle: style
                ], range: lineRange)
                return
            }

            if isHorizontalRule(trimmed) {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 3
                style.paragraphSpacingBefore = enhanced ? 6 : 2
                style.paragraphSpacing = enhanced ? 6 : 2
                attributed.addAttributes([
                    .foregroundColor: enhanced ? palette.border : palette.weakText,
                    .font: NSFont.systemFont(ofSize: enhanced ? max(baseFontSize * 0.72, 9) : baseFontSize, weight: .medium),
                    .paragraphStyle: style
                ], range: lineRange)
                return
            }

            if listMarkerRange(in: line, lineRange: lineRange) != nil {
                let style = NSMutableParagraphStyle()
                style.headIndent = 18
                style.firstLineHeadIndent = 0
                style.lineSpacing = 3
                attributed.addAttribute(.paragraphStyle, value: style, range: lineRange)
                if enhanced {
                    if let task = taskListRanges(in: line, lineRange: lineRange) {
                        attributed.addAttribute(.foregroundColor, value: palette.weakText, range: task.markerRange)
                        if task.isDone {
                            attributed.addAttributes([
                                .foregroundColor: palette.weakText,
                                .strikethroughStyle: NSUnderlineStyle.single.rawValue
                            ], range: task.contentRange)
                        }
                    } else if let marker = listMarkerRange(in: line, lineRange: lineRange) {
                        attributed.addAttribute(.foregroundColor, value: palette.weakText, range: marker)
                    }
                }
            }
        }
    }

    private static func applyInlineStyles(
        to attributed: NSMutableAttributedString,
        text: String,
        baseFontSize: CGFloat,
        palette: PaperPalette,
        enhanced: Bool
    ) {
        for span in MarkdownInlineParser.inlineSpans(in: text) {
            if enhanced {
                for markerRange in span.markerRanges where markerRange.length > 0 {
                    attributed.addAttribute(.foregroundColor, value: palette.weakText, range: markerRange)
                }
            }

            switch span.kind {
            case .bold:
                attributed.addAttribute(
                    .font,
                    value: NSFont.systemFont(ofSize: baseFontSize, weight: .semibold),
                    range: span.contentRange
                )
            case .italic:
                attributed.addAttribute(
                    .font,
                    value: NSFontManager.shared.convert(NSFont.systemFont(ofSize: baseFontSize), toHaveTrait: .italicFontMask),
                    range: span.contentRange
                )
            case .strikethrough:
                attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: span.contentRange)
            case .underline:
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: span.contentRange)
            case .code:
                applyInlineCodeStyle(to: attributed, range: span.contentRange, baseFontSize: baseFontSize, palette: palette)
            case .link:
                guard let rawURL = span.url,
                      let url = URL(string: rawURL) else {
                    continue
                }
                attributed.addAttributes([
                    .link: url,
                    .foregroundColor: palette.active,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: span.contentRange)
            }
        }
    }

    private static func applyInlineCodeStyle(to attributed: NSMutableAttributedString, range: NSRange, baseFontSize: CGFloat, palette: PaperPalette) {
        attributed.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize * 0.95, weight: .regular),
            .foregroundColor: palette.active,
            .backgroundColor: palette.hover.withAlphaComponent(0.55)
        ], range: range)
    }

    private static func fencedCodeBlockRanges(in text: String) -> [NSRange] {
        MarkdownInlineParser.fencedCodeBlockRanges(in: text)
    }

    private static func headingLevel(in line: String) -> Int? {
        let count = line.prefix { $0 == "#" }.count
        guard count > 0, count <= 6 else { return nil }
        let after = line.dropFirst(count)
        return after.first == " " ? count : nil
    }

    private static func markerRange(prefix: Character, in line: String, lineRange: NSRange) -> NSRange {
        let count = line.prefix { $0 == prefix }.count
        return NSRange(location: lineRange.location, length: min(count, lineRange.length))
    }

    private static func listMarkerRange(in line: String, lineRange: NSRange) -> NSRange? {
        let nsLine = line as NSString
        let patterns = [#"^\s*[-*+]\s+"#, #"^\s*\d+[.)]\s+"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
                continue
            }
            return NSRange(location: lineRange.location + match.range.location, length: match.range.length)
        }
        return nil
    }

    private static func taskListRanges(in line: String, lineRange: NSRange) -> (markerRange: NSRange, contentRange: NSRange, isDone: Bool)? {
        let nsLine = line as NSString
        let pattern = #"^\s*(?:[-*+]|\d+[.)])\s+\[([ xX])\]\s+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
            return nil
        }
        let marker = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
        let contentLocation = marker.location + marker.length
        let contentLength = max(0, lineRange.location + lineRange.length - contentLocation)
        let checkbox = nsLine.substring(with: match.range(at: 1))
        return (
            markerRange: marker,
            contentRange: NSRange(location: contentLocation, length: contentLength),
            isDone: checkbox.lowercased() == "x"
        )
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        return Set(compact).isSubset(of: ["-"]) || Set(compact).isSubset(of: ["*"]) || Set(compact).isSubset(of: ["_"])
    }
}
