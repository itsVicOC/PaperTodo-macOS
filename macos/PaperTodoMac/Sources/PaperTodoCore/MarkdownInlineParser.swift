import Foundation

public enum MarkdownInlineParser {
    public enum SpanKind: Equatable {
        case bold
        case italic
        case strikethrough
        case underline
        case code
        case link
    }

    public enum SpanSource: Equatable {
        case markdown
        case html
        case rawURL
    }

    public struct Span: Equatable {
        public let kind: SpanKind
        public let source: SpanSource
        public let range: NSRange
        public let contentRange: NSRange
        public let markerRanges: [NSRange]
        public let tagName: String?
        public let url: String?
    }

    private struct HtmlInlineSpan {
        let range: NSRange
        let openRange: NSRange
        let closeRange: NSRange
        let contentRange: NSRange
        let tagName: String
        let url: String?
    }

    public static func inlineSpans(in text: String) -> [Span] {
        guard !text.isEmpty else { return [] }

        let fencedRanges = fencedCodeBlockRanges(in: text)
        var spans: [Span] = []
        var codeRanges = fencedRanges

        let markdownCodeSpans = regexSpans(
            #"`([^`\n]+)`"#,
            kind: .code,
            source: .markdown,
            text: text,
            ignoredRanges: fencedRanges
        )
        spans.append(contentsOf: markdownCodeSpans)
        codeRanges.append(contentsOf: markdownCodeSpans.map(\.range))

        let htmlCodeSpans = htmlInlineSpans(in: text, ignoredRanges: codeRanges)
            .filter { $0.tagName == "code" }
            .map { htmlSpan($0, kind: .code) }
        spans.append(contentsOf: htmlCodeSpans)
        codeRanges.append(contentsOf: htmlCodeSpans.map(\.range))

        let ignoredInlineRanges = codeRanges
        spans.append(contentsOf: regexSpans(
            #"\*\*([^*\n]+)\*\*|__([^_\n]+)__"#,
            kind: .bold,
            source: .markdown,
            text: text,
            ignoredRanges: ignoredInlineRanges
        ))
        spans.append(contentsOf: regexSpans(
            #"(?<!\*)\*([^*\n]+)\*(?!\*)|(?<!_)_([^_\n]+)_(?!_)"#,
            kind: .italic,
            source: .markdown,
            text: text,
            ignoredRanges: ignoredInlineRanges
        ))
        spans.append(contentsOf: regexSpans(
            #"~~([^~\n]+)~~"#,
            kind: .strikethrough,
            source: .markdown,
            text: text,
            ignoredRanges: ignoredInlineRanges
        ))

        let htmlStyleSpans = htmlInlineSpans(in: text, ignoredRanges: ignoredInlineRanges)
            .compactMap { html -> Span? in
                switch html.tagName {
                case "b", "strong":
                    return htmlSpan(html, kind: .bold)
                case "i", "em":
                    return htmlSpan(html, kind: .italic)
                case "s", "del":
                    return htmlSpan(html, kind: .strikethrough)
                case "u":
                    return htmlSpan(html, kind: .underline)
                case "a":
                    return htmlSpan(html, kind: .link)
                default:
                    return nil
                }
            }
        spans.append(contentsOf: htmlStyleSpans)

        let htmlLinkRanges = htmlStyleSpans
            .filter { $0.kind == .link }
            .map(\.range)
        let markdownLinks = markdownLinkSpans(in: text, ignoredRanges: ignoredInlineRanges + htmlLinkRanges)
        spans.append(contentsOf: markdownLinks)
        var linkRanges = ignoredInlineRanges + htmlLinkRanges
        linkRanges.append(contentsOf: markdownLinks.map(\.range))

        spans.append(contentsOf: rawURLSpans(in: text, ignoredRanges: linkRanges))
        return spans.sorted {
            if $0.range.location == $1.range.location {
                return $0.range.length < $1.range.length
            }
            return $0.range.location < $1.range.location
        }
    }

    public static func linkURL(in text: String, at utf16Offset: Int) -> String? {
        guard utf16Offset >= 0 else { return nil }

        return inlineSpans(in: text)
            .first { span in
                span.kind == .link &&
                    NSLocationInRange(utf16Offset, span.range)
            }?
            .url
    }

    public static func fencedCodeBlockRanges(in text: String) -> [NSRange] {
        let nsText = text as NSString
        var ranges: [NSRange] = []
        var blockStart: Int?
        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("```") else { return }

            if let start = blockStart {
                ranges.append(NSRange(location: start, length: NSMaxRange(lineRange) - start))
                blockStart = nil
            } else {
                blockStart = lineRange.location
            }
        }

        if let start = blockStart {
            ranges.append(NSRange(location: start, length: nsText.length - start))
        }
        return ranges
    }

    private static func regexSpans(
        _ pattern: String,
        kind: SpanKind,
        source: SpanSource,
        text: String,
        ignoredRanges: [NSRange]
    ) -> [Span] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, range: fullRange).compactMap { match in
            let range = match.range
            guard !intersects(range, ignoredRanges) else { return nil }
            let contentRange = firstCaptureRange(in: match) ?? range
            return Span(
                kind: kind,
                source: source,
                range: range,
                contentRange: contentRange,
                markerRanges: markerRanges(for: range, contentRange: contentRange),
                tagName: nil,
                url: nil
            )
        }
    }

    private static func markdownLinkSpans(in text: String, ignoredRanges: [NSRange]) -> [Span] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!!)\[([^\]\n]+)\]\(([^)\s\n]+)\)"#, options: [.caseInsensitive]) else {
            return []
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, range: fullRange).compactMap { match in
            let range = match.range
            guard !intersects(range, ignoredRanges),
                  match.numberOfRanges > 2,
                  let url = normalizedURL(nsText.substring(with: match.range(at: 2))) else {
                return nil
            }

            let contentRange = match.range(at: 1)
            return Span(
                kind: .link,
                source: .markdown,
                range: range,
                contentRange: contentRange,
                markerRanges: markerRanges(for: range, contentRange: contentRange),
                tagName: nil,
                url: url
            )
        }
    }

    private static func rawURLSpans(in text: String, ignoredRanges: [NSRange]) -> [Span] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\]\()https?://[^\s<>)]+"#, options: [.caseInsensitive]) else {
            return []
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, range: fullRange).compactMap { match in
            let range = match.range
            guard !intersects(range, ignoredRanges),
                  let url = normalizedURL(nsText.substring(with: range)) else {
                return nil
            }
            return Span(
                kind: .link,
                source: .rawURL,
                range: range,
                contentRange: range,
                markerRanges: [],
                tagName: nil,
                url: url
            )
        }
    }

    private static func htmlInlineSpans(in text: String, ignoredRanges: [NSRange]) -> [HtmlInlineSpan] {
        let nsText = text as NSString
        var spans: [HtmlInlineSpan] = []
        var search = 0

        while search < nsText.length {
            let openStart = nsText.range(of: "<", options: [], range: NSRange(location: search, length: nsText.length - search)).location
            if openStart == NSNotFound {
                break
            }

            guard let opening = parseHtmlOpeningTag(in: nsText, openStart: openStart),
                  let closing = findHtmlClosingTag(in: nsText, tagName: opening.tagName, searchStart: opening.openEnd, limit: opening.lineEnd) else {
                search = openStart + 1
                continue
            }

            if closing.closeStart > opening.openEnd {
                let fullRange = NSRange(location: openStart, length: closing.closeEnd - openStart)
                if !intersects(fullRange, ignoredRanges) {
                    spans.append(HtmlInlineSpan(
                        range: fullRange,
                        openRange: NSRange(location: openStart, length: opening.openEnd - openStart),
                        closeRange: NSRange(location: closing.closeStart, length: closing.closeEnd - closing.closeStart),
                        contentRange: NSRange(location: opening.openEnd, length: closing.closeStart - opening.openEnd),
                        tagName: opening.tagName,
                        url: opening.url
                    ))
                }
            }

            search = closing.closeEnd
        }

        return spans
    }

    private static func htmlSpan(_ html: HtmlInlineSpan, kind: SpanKind) -> Span {
        Span(
            kind: kind,
            source: .html,
            range: html.range,
            contentRange: html.contentRange,
            markerRanges: [html.openRange, html.closeRange],
            tagName: html.tagName,
            url: html.url
        )
    }

    private static func parseHtmlOpeningTag(
        in text: NSString,
        openStart: Int
    ) -> (tagName: String, openEnd: Int, lineEnd: Int, url: String?)? {
        guard openStart + 2 < text.length,
              text.character(at: openStart) == ascii("<"),
              text.character(at: openStart + 1) != ascii("/") else {
            return nil
        }

        let lineEnd = endOfLine(in: text, from: openStart)
        var nameEnd = openStart + 1
        while nameEnd < lineEnd, isHtmlTagNameChar(text.character(at: nameEnd)) {
            nameEnd += 1
        }

        guard nameEnd > openStart + 1 else { return nil }

        let tagName = text.substring(with: NSRange(location: openStart + 1, length: nameEnd - openStart - 1)).lowercased()
        guard isSupportedHtmlInlineTag(tagName),
              let tagEnd = findHtmlTagEnd(in: text, from: nameEnd, limit: lineEnd) else {
            return nil
        }

        let attributes = text.substring(with: NSRange(location: nameEnd, length: tagEnd - nameEnd))
        let url: String?
        if tagName == "a" {
            guard let href = htmlHrefAttribute(in: attributes),
                  let normalized = normalizedURL(href) else {
                return nil
            }
            url = normalized
        } else {
            guard attributes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            url = nil
        }

        return (tagName, tagEnd + 1, lineEnd, url)
    }

    private static func findHtmlClosingTag(
        in text: NSString,
        tagName: String,
        searchStart: Int,
        limit: Int
    ) -> (closeStart: Int, closeEnd: Int)? {
        var search = searchStart
        while search < limit {
            let start = text.range(of: "</", options: [], range: NSRange(location: search, length: limit - search)).location
            if start == NSNotFound {
                return nil
            }

            var nameEnd = start + 2
            while nameEnd < limit, isHtmlTagNameChar(text.character(at: nameEnd)) {
                nameEnd += 1
            }

            if nameEnd > start + 2 {
                let candidate = text.substring(with: NSRange(location: start + 2, length: nameEnd - start - 2))
                var end = nameEnd
                while end < limit, isHorizontalWhitespace(text.character(at: end)) {
                    end += 1
                }

                if candidate.caseInsensitiveCompare(tagName) == .orderedSame,
                   end < limit,
                   text.character(at: end) == ascii(">") {
                    return (start, end + 1)
                }
            }

            search = start + 2
        }

        return nil
    }

    private static func findHtmlTagEnd(in text: NSString, from start: Int, limit: Int) -> Int? {
        var quote: unichar?
        var index = start

        while index < limit {
            let character = text.character(at: index)
            if let currentQuote = quote {
                if character == currentQuote {
                    quote = nil
                }
                index += 1
                continue
            }

            if character == ascii("\"") || character == ascii("'") {
                quote = character
            } else if character == ascii(">") {
                return index
            }

            index += 1
        }

        return nil
    }

    private static func htmlHrefAttribute(in attributes: String) -> String? {
        var index = attributes.startIndex

        while index < attributes.endIndex {
            while index < attributes.endIndex, attributes[index].isWhitespace {
                index = attributes.index(after: index)
            }

            let nameStart = index
            while index < attributes.endIndex, isHtmlAttributeNameChar(attributes[index]) {
                index = attributes.index(after: index)
            }

            guard index > nameStart else { return nil }
            let name = String(attributes[nameStart..<index])

            while index < attributes.endIndex, attributes[index].isWhitespace {
                index = attributes.index(after: index)
            }

            guard index < attributes.endIndex, attributes[index] == "=" else { return nil }
            index = attributes.index(after: index)

            while index < attributes.endIndex, attributes[index].isWhitespace {
                index = attributes.index(after: index)
            }
            guard index < attributes.endIndex else { return nil }

            let value: String
            if attributes[index] == "\"" || attributes[index] == "'" {
                let quote = attributes[index]
                let valueStart = attributes.index(after: index)
                guard let valueEnd = attributes[valueStart...].firstIndex(of: quote) else {
                    return nil
                }
                value = String(attributes[valueStart..<valueEnd])
                index = attributes.index(after: valueEnd)
            } else {
                let valueStart = index
                while index < attributes.endIndex, !attributes[index].isWhitespace {
                    index = attributes.index(after: index)
                }
                value = String(attributes[valueStart..<index])
            }

            if name.caseInsensitiveCompare("href") == .orderedSame {
                return value
            }
        }

        return nil
    }

    private static func normalizedURL(_ rawURL: String) -> String? {
        var trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }

        if trimmed.lowercased().hasPrefix("www.") {
            trimmed = "https://" + trimmed
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "mailto" else {
            return nil
        }

        return url.absoluteString
    }

    private static func firstCaptureRange(in match: NSTextCheckingResult) -> NSRange? {
        for index in 1..<match.numberOfRanges {
            let range = match.range(at: index)
            if range.location != NSNotFound {
                return range
            }
        }
        return nil
    }

    private static func markerRanges(for range: NSRange, contentRange: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        if contentRange.location > range.location {
            ranges.append(NSRange(location: range.location, length: contentRange.location - range.location))
        }

        let contentEnd = NSMaxRange(contentRange)
        let rangeEnd = NSMaxRange(range)
        if contentEnd < rangeEnd {
            ranges.append(NSRange(location: contentEnd, length: rangeEnd - contentEnd))
        }
        return ranges
    }

    private static func intersects(_ range: NSRange, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange(range, $0).length > 0 }
    }

    private static func endOfLine(in text: NSString, from start: Int) -> Int {
        var index = start
        while index < text.length {
            let character = text.character(at: index)
            if character == ascii("\n") || character == ascii("\r") {
                return index
            }
            index += 1
        }
        return text.length
    }

    private static func isSupportedHtmlInlineTag(_ tagName: String) -> Bool {
        tagName == "b" ||
            tagName == "strong" ||
            tagName == "i" ||
            tagName == "em" ||
            tagName == "s" ||
            tagName == "del" ||
            tagName == "u" ||
            tagName == "code" ||
            tagName == "a"
    }

    private static func isHtmlTagNameChar(_ character: unichar) -> Bool {
        (character >= ascii("A") && character <= ascii("Z")) ||
            (character >= ascii("a") && character <= ascii("z"))
    }

    private static func isHtmlAttributeNameChar(_ character: Character) -> Bool {
        character.isASCII &&
            (character.isLetter || character.isNumber || character == "-" || character == "_")
    }

    private static func isHorizontalWhitespace(_ character: unichar) -> Bool {
        character == ascii(" ") || character == ascii("\t")
    }

    private static func ascii(_ character: Character) -> unichar {
        unichar(String(character).utf16.first ?? 0)
    }
}
