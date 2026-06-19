import XCTest
@testable import PaperTodoCore

final class MarkdownInlineParserTests: XCTestCase {
    func testSupportedHtmlInlineTagsProduceContentSpans() {
        let text = "<b>bold</b> <strong>strong</strong> <i>italic</i> <em>em</em> <s>strike</s> <del>delete</del> <u>under</u> <code>code</code>"
        let spans = MarkdownInlineParser.inlineSpans(in: text)

        XCTAssertEqual(spans.map(\.tagName), ["b", "strong", "i", "em", "s", "del", "u", "code"])
        XCTAssertEqual(spans.map(\.kind), [.bold, .bold, .italic, .italic, .strikethrough, .strikethrough, .underline, .code])
        XCTAssertEqual(spans.map { substring(text, $0.contentRange) }, ["bold", "strong", "italic", "em", "strike", "delete", "under", "code"])
        XCTAssertTrue(spans.allSatisfy { $0.source == .html })
        XCTAssertTrue(spans.allSatisfy { $0.markerRanges.count == 2 })
    }

    func testHtmlAnchorExtractsNormalizedURL() {
        let text = #"See <a href="https://example.com/path">example</a> now"#
        let spans = MarkdownInlineParser.inlineSpans(in: text)

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].kind, .link)
        XCTAssertEqual(spans[0].tagName, "a")
        XCTAssertEqual(spans[0].url, "https://example.com/path")
        XCTAssertEqual(substring(text, spans[0].contentRange), "example")
    }

    func testHtmlInlineTagsMustStayOnOneLine() {
        let text = "<b>first\nsecond</b>\n<a href=\"https://example.com\">first\nsecond</a>"
        let spans = MarkdownInlineParser.inlineSpans(in: text)

        XCTAssertTrue(spans.isEmpty)
    }

    func testHtmlTagsInsideInlineCodeAreIgnored() {
        let text = "`<b>code</b>` <i>real</i>"
        let spans = MarkdownInlineParser.inlineSpans(in: text)

        XCTAssertEqual(spans.map(\.kind), [.code, .italic])
        XCTAssertEqual(spans.map { substring(text, $0.contentRange) }, ["<b>code</b>", "real"])
        XCTAssertNil(spans[0].tagName)
        XCTAssertEqual(spans[1].tagName, "i")
    }

    func testHtmlTagsInsideFencedCodeAreIgnored() {
        let text = "```\n<b>code</b>\n```\n<strong>real</strong>"
        let spans = MarkdownInlineParser.inlineSpans(in: text)

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].kind, .bold)
        XCTAssertEqual(spans[0].tagName, "strong")
        XCTAssertEqual(substring(text, spans[0].contentRange), "real")
    }

    func testUnsupportedOrAttributedHtmlTagsAreIgnored() {
        let text = #"<img src="x"> <div>block</div> <b class="loud">bold</b> <a title="x" href="https://example.com">link</a>"#
        let spans = MarkdownInlineParser.inlineSpans(in: text)

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].kind, .link)
        XCTAssertEqual(spans[0].tagName, "a")
        XCTAssertEqual(substring(text, spans[0].contentRange), "link")
    }

    func testNestedLinkSyntaxInsideHtmlAnchorIsNotParsedTwice() {
        let text = #"<a href="https://example.com">[label](https://example.org) https://example.net</a>"#
        let spans = MarkdownInlineParser.inlineSpans(in: text)

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].kind, .link)
        XCTAssertEqual(spans[0].source, .html)
        XCTAssertEqual(spans[0].url, "https://example.com")
        XCTAssertEqual(substring(text, spans[0].contentRange), "[label](https://example.org) https://example.net")
    }

    func testMarkdownLinksAndRawURLsIgnoreCodeRanges() {
        let text = "`https://example.com/code` [label](https://example.com/doc) https://example.com/raw"
        let spans = MarkdownInlineParser.inlineSpans(in: text)

        XCTAssertEqual(spans.map(\.kind), [.code, .link, .link])
        XCTAssertEqual(spans.map(\.source), [.markdown, .markdown, .rawURL])
        XCTAssertEqual(spans.map { substring(text, $0.contentRange) }, ["https://example.com/code", "label", "https://example.com/raw"])
        XCTAssertEqual(spans[1].url, "https://example.com/doc")
        XCTAssertEqual(spans[2].url, "https://example.com/raw")
    }

    func testLinkURLFindsMarkdownHtmlAndRawLinksByOffset() {
        let text = #"A [label](https://example.com/doc) <a href="https://example.com/html">html</a> https://example.com/raw"#

        XCTAssertEqual(MarkdownInlineParser.linkURL(in: text, at: location(of: "label", in: text)), "https://example.com/doc")
        XCTAssertEqual(MarkdownInlineParser.linkURL(in: text, at: location(of: "https://example.com/doc", in: text)), "https://example.com/doc")
        XCTAssertEqual(MarkdownInlineParser.linkURL(in: text, at: location(of: "html", in: text)), "https://example.com/html")
        XCTAssertEqual(MarkdownInlineParser.linkURL(in: text, at: location(of: "https://example.com/raw", in: text)), "https://example.com/raw")
        XCTAssertNil(MarkdownInlineParser.linkURL(in: text, at: location(of: "A", in: text)))
    }

    func testLinkURLIgnoresURLsInsideCode() {
        let text = "`https://example.com/code`\n```\nhttps://example.com/block\n```\nhttps://example.com/real"

        XCTAssertNil(MarkdownInlineParser.linkURL(in: text, at: location(of: "https://example.com/code", in: text)))
        XCTAssertNil(MarkdownInlineParser.linkURL(in: text, at: location(of: "https://example.com/block", in: text)))
        XCTAssertEqual(MarkdownInlineParser.linkURL(in: text, at: location(of: "https://example.com/real", in: text)), "https://example.com/real")
    }

    private func substring(_ text: String, _ range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    private func location(of needle: String, in text: String) -> Int {
        let range = (text as NSString).range(of: needle)
        XCTAssertNotEqual(range.location, NSNotFound)
        return range.location
    }
}
