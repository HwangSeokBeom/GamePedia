import UIKit
import XCTest
@testable import GamePedia

// MARK: - ArticleMarkdownRendererTests
//
// Required areas 19 and 20: an article body must never introduce markup, a
// remote resource, or a link the app would be unwilling to open.

final class ArticleMarkdownRendererTests: XCTestCase {

    private func render(_ markdown: String) throws -> ArticleMarkdownRenderer.Output {
        try ArticleMarkdownRenderer.render(markdown: markdown)
    }

    // MARK: 19 — raw HTML is never interpreted

    func testRawHTMLIsShownAsTextAndNeverAsMarkup() throws {
        let body = """
        <script>alert('xss')</script>

        <img src="https://evil.example/tracker.gif">

        <a href="javascript:alert(1)">tap me</a>

        <b>bold?</b>
        """
        let output = try render(body)
        let text = output.attributedString.string

        // The characters survive as characters — which is the point: there is
        // no parser here that could treat them as markup, and no web view that
        // could execute them.
        XCTAssertTrue(text.contains("<script>"), "raw HTML must remain literal text")
        XCTAssertTrue(text.contains("alert('xss')"))
        XCTAssertTrue(text.contains("<b>bold?</b>"))

        // Nothing became a link or an image.
        assertNoLinks(in: output.attributedString)
        assertNoAttachments(in: output.attributedString)
    }

    func testNoAttributeInTheOutputCanTriggerARemoteFetch() throws {
        let output = try render("Normal text with **bold** and `code`.")
        assertNoAttachments(in: output.attributedString)
        assertNoLinks(in: output.attributedString)
    }

    // MARK: 19 — inline images are removed

    func testInlineImagesAreStrippedButTheirAltTextSurvives() throws {
        let output = try render("Before ![a screenshot](https://cdn.example/x.png) after.")
        XCTAssertEqual(output.removedImageCount, 1)
        XCTAssertEqual(output.attributedString.string, "Before a screenshot after.")
        assertNoAttachments(in: output.attributedString)
    }

    func testEveryInlineImageIsRemovedRegardlessOfScheme() throws {
        let output = try render("""
        ![one](https://cdn.example/1.png) and ![two](http://cdn.example/2.png)
        and ![three](data:image/png;base64,AAAA) and ![four](/relative.png)
        """)
        XCTAssertEqual(output.removedImageCount, 4, "no image is rendered, https or not")
        for excluded in ["cdn.example", "data:image", "relative.png"] {
            XCTAssertFalse(output.attributedString.string.contains(excluded))
        }
        assertNoAttachments(in: output.attributedString)
    }

    func testAnEscapedImageMarkerIsLeftAsText() throws {
        let output = try render(#"Literal \![not an image](x) here."#)
        XCTAssertEqual(output.removedImageCount, 0)
        XCTAssertTrue(output.attributedString.string.contains("not an image"))
    }

    // MARK: 20 — only https links survive

    func testHTTPSLinksAreKept() throws {
        let output = try render("See [the source](https://example.com/article).")
        let links = collectLinks(in: output.attributedString)
        XCTAssertEqual(links.map(\.absoluteString), ["https://example.com/article"])
        XCTAssertEqual(output.removedLinkCount, 0)
    }

    func testDangerousAndInsecureLinksLoseTheirDestination() throws {
        for (label, url) in [
            ("js", "javascript:alert(1)"),
            ("data", "data:text/html;base64,PHNjcmlwdD4="),
            ("plain", "http://insecure.example/x"),
            ("file", "file:///etc/passwd"),
            ("relative", "/somewhere")
        ] {
            let output = try render("Tap [\(label)](\(url)) now.")
            assertNoLinks(in: output.attributedString, "\(url) must not remain tappable")
            // The words still read, so the sentence is not mangled.
            XCTAssertTrue(output.attributedString.string.contains(label))
        }
    }

    func testAMixedBodyKeepsOnlyTheSafeLink() throws {
        let output = try render(
            "[safe](https://ok.example) and [unsafe](javascript:alert(1)) and ![img](https://x/y.png)"
        )
        let links = collectLinks(in: output.attributedString)
        XCTAssertEqual(links.map(\.absoluteString), ["https://ok.example"])
        XCTAssertEqual(output.removedLinkCount, 1)
        XCTAssertEqual(output.removedImageCount, 1)
    }

    // MARK: Block structure still renders

    func testHeadingsListsQuotesAndCodeAllRender() throws {
        let output = try render("""
        # Title

        A paragraph with **bold** text.

        - first
        - second

        1. one
        2. two

        > a quotation

        ```
        <script>this is inside a fence</script>
        ```
        """)
        let text = output.attributedString.string

        XCTAssertTrue(text.contains("Title"))
        XCTAssertTrue(text.contains("bold"))
        XCTAssertTrue(text.contains("• first"))
        XCTAssertTrue(text.contains("1. one"))
        XCTAssertTrue(text.contains("a quotation"))
        // A fence is literal by definition, so its contents cannot smuggle
        // anything past the inline filter either.
        XCTAssertTrue(text.contains("<script>this is inside a fence</script>"))
        assertNoLinks(in: output.attributedString)
        assertNoAttachments(in: output.attributedString)

        // Headings are visually distinct from body text.
        let headingFont = output.attributedString.attribute(
            .font, at: 0, effectiveRange: nil
        ) as? UIFont
        XCTAssertNotNil(headingFont)
        XCTAssertGreaterThan(
            headingFont?.pointSize ?? 0,
            UIFont.preferredFont(forTextStyle: .body).pointSize
        )
    }

    func testAnEmptyOrWhitespaceBodyRendersNothingRatherThanCrashing() throws {
        XCTAssertEqual(try render("").attributedString.length, 0)
        XCTAssertEqual(try render("   \n\n  \n").attributedString.length, 0)
    }

    func testAMalformedBodyStillShowsTheReaderSomething() throws {
        let output = try render("Unclosed [link( and **bold and `code")
        XCTAssertGreaterThan(output.attributedString.length, 0)
    }

    // MARK: Rendering goes through the article, which pins its format

    func testRenderingAnArticleUsesTheDeclaredBody() throws {
        let article = Article(
            slug: "s",
            status: .corrected,
            locale: "ko",
            headline: "H",
            excerpt: "E",
            bodyMarkdown: "본문 [출처](https://example.com) 입니다.",
            publishedAt: nil,
            correctedAt: Date(),
            revision: .init(number: 2, status: .corrected, changeNote: "정정", createdAt: Date()),
            heroImageWithheldReason: nil,
            sources: []
        )
        let output = try ArticleMarkdownRenderer.renderIfSupported(article)
        XCTAssertTrue(output.attributedString.string.contains("본문"))
        XCTAssertEqual(collectLinks(in: output.attributedString).count, 1)
        XCTAssertEqual(Article.supportedBodyFormat, "commonmark-no-html")
    }

    // MARK: Helpers

    private func collectLinks(in string: NSAttributedString) -> [URL] {
        var urls: [URL] = []
        string.enumerateAttribute(.link, in: NSRange(location: 0, length: string.length)) { value, _, _ in
            if let url = value as? URL { urls.append(url) }
            if let raw = value as? String, let url = URL(string: raw) { urls.append(url) }
        }
        return urls
    }

    private func assertNoLinks(
        in string: NSAttributedString,
        _ message: String = "no link may survive",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(collectLinks(in: string).isEmpty, message, file: file, line: line)
    }

    private func assertNoAttachments(
        in string: NSAttributedString,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var found = false
        let range = NSRange(location: 0, length: string.length)
        string.enumerateAttribute(.attachment, in: range) { value, _, _ in
            if value != nil { found = true }
        }
        XCTAssertFalse(found, "no attachment may be produced from a body", file: file, line: line)
    }
}
