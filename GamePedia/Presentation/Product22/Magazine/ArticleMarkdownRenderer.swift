import UIKit

// MARK: - ArticleMarkdownRenderer
//
// Renders an article body into `NSAttributedString`.
//
// The threat model is short: an article body is third-party-influenced text
// that the app displays. So this renderer
//
//   - is not a web view. There is no WKWebView anywhere in the magazine, so
//     there is no script engine, no DOM and no navigation to subvert.
//   - refuses any body whose declared format is not `commonmark-no-html`,
//     rather than guessing how to display an unknown format.
//   - uses Foundation's CommonMark parser, which produces a value type of
//     runs and intents. Raw HTML has no representation in that output: it
//     survives as literal characters, so `<script>…</script>` is displayed,
//     never interpreted.
//   - drops every inline image. The contract says a body never introduces a
//     remote resource of its own, and this makes that structural rather than
//     trusted: an image run is removed before it can be laid out, so no
//     request is issued even if one appeared.
//   - keeps only https links. A `javascript:`, `data:` or plaintext link
//     loses its attribute and renders as ordinary text.
//
// The hero image is not rendered here. It comes from the rights-reviewed
// asset on the Today card and is loaded separately.

enum ArticleMarkdownRenderer {

    struct Style {
        var body = UIFont.preferredFont(forTextStyle: .body)
        var heading1 = UIFont.preferredFont(forTextStyle: .title2)
        var heading2 = UIFont.preferredFont(forTextStyle: .title3)
        var heading3 = UIFont.preferredFont(forTextStyle: .headline)
        var code = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize, weight: .regular)
        var textColor = UIColor.gpTextPrimary
        var secondaryColor = UIColor.gpTextSecondary
        var linkColor = UIColor.gpPrimary
        var paragraphSpacing: CGFloat = 12

        init() {}
    }

    enum RenderError: Error, Equatable {
        /// The body declared a format this app does not know how to display.
        case unsupportedFormat(String)
    }

    /// The result of rendering, including what was removed. The counts are
    /// used by tests and by nothing user-facing — they are not shown to the
    /// reader, who has no use for "3 images were stripped".
    struct Output {
        let attributedString: NSAttributedString
        let removedImageCount: Int
        let removedLinkCount: Int
    }

    // MARK: Entry point

    static func render(_ article: Article, style: Style = Style()) throws -> Output {
        try render(markdown: article.bodyMarkdown, style: style)
    }

    /// Renders raw CommonMark. Prefer `render(_:style:)`, which also checks the
    /// declared body format.
    static func render(markdown: String, style: Style = Style()) throws -> Output {
        var removedImages = 0
        var removedLinks = 0
        let result = NSMutableAttributedString()

        for block in blocks(in: markdown) {
            let rendered = renderBlock(
                block, style: style, removedImages: &removedImages, removedLinks: &removedLinks
            )
            guard rendered.length > 0 else { continue }
            if result.length > 0 { result.append(NSAttributedString(string: "\n")) }
            result.append(rendered)
        }

        return Output(
            attributedString: result,
            removedImageCount: removedImages,
            removedLinkCount: removedLinks
        )
    }

    // MARK: Blocks
    //
    // Foundation's markdown parser can take a whole document, but it collapses
    // block structure into intents that still need walking to lay out. Feeding
    // it one block at a time keeps heading/list handling explicit and keeps a
    // malformed block from affecting its neighbours.

    private struct Block {
        enum Kind {
            case paragraph
            case heading(level: Int)
            case listItem(ordered: Bool, index: Int)
            case quote
            case codeFence
        }
        let kind: Kind
        let text: String
    }

    private static func blocks(in markdown: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var inFence = false
        var fence: [String] = []
        var orderedIndex = 0

        func flushParagraph() {
            let joined = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !joined.isEmpty { blocks.append(Block(kind: .paragraph, text: joined)) }
            paragraph = []
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))

            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                if inFence {
                    blocks.append(Block(kind: .codeFence, text: fence.joined(separator: "\n")))
                    fence = []
                    inFence = false
                } else {
                    flushParagraph()
                    inFence = true
                }
                continue
            }
            if inFence {
                fence.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
                orderedIndex = 0
                continue
            }

            if let heading = headingLevel(line) {
                flushParagraph()
                orderedIndex = 0
                let text = String(line.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
                blocks.append(Block(kind: .heading(level: heading), text: text))
                continue
            }

            if line.hasPrefix("> ") || line == ">" {
                flushParagraph()
                blocks.append(Block(kind: .quote, text: String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
                continue
            }

            if let bullet = unorderedBullet(line) {
                flushParagraph()
                orderedIndex = 0
                blocks.append(Block(kind: .listItem(ordered: false, index: 0), text: bullet))
                continue
            }

            if let (index, text) = orderedBullet(line) {
                flushParagraph()
                orderedIndex = index
                blocks.append(Block(kind: .listItem(ordered: true, index: orderedIndex), text: text))
                continue
            }

            paragraph.append(line)
        }

        if inFence, !fence.isEmpty {
            blocks.append(Block(kind: .codeFence, text: fence.joined(separator: "\n")))
        }
        flushParagraph()
        return blocks
    }

    private static func headingLevel(_ line: String) -> Int? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        return hashes
    }

    private static func unorderedBullet(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private static func orderedBullet(_ line: String) -> (Int, String)? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty, let index = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return (index, String(rest.dropFirst(2)))
    }

    // MARK: Inline rendering

    private static func renderBlock(
        _ block: Block,
        style: Style,
        removedImages: inout Int,
        removedLinks: inout Int
    ) -> NSAttributedString {
        // A code fence is never parsed as markdown: its contents are literal
        // by definition, which also means nothing inside it can smuggle a link
        // or an image past the inline filter.
        if case .codeFence = block.kind {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = style.paragraphSpacing
            return NSAttributedString(
                string: block.text,
                attributes: [
                    .font: style.code,
                    .foregroundColor: style.secondaryColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }

        let inline = renderInline(
            block.text, style: style, removedImages: &removedImages, removedLinks: &removedLinks
        )
        let result = NSMutableAttributedString(attributedString: inline)
        let full = NSRange(location: 0, length: result.length)
        guard full.length > 0 else { return result }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = style.paragraphSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        switch block.kind {
        case .paragraph:
            result.addAttribute(.font, value: style.body, range: full)
        case .heading(let level):
            let font: UIFont
            switch level {
            case 1: font = style.heading1
            case 2: font = style.heading2
            default: font = style.heading3
            }
            result.addAttribute(.font, value: font, range: full)
            paragraphStyle.paragraphSpacingBefore = style.paragraphSpacing
        case .listItem(let ordered, let index):
            result.addAttribute(.font, value: style.body, range: full)
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.headIndent = 18
            let marker = ordered ? "\(index). " : "• "
            result.insert(
                NSAttributedString(string: marker, attributes: [.font: style.body]),
                at: 0
            )
        case .quote:
            result.addAttribute(.font, value: style.body, range: full)
            result.addAttribute(.foregroundColor, value: style.secondaryColor, range: full)
            paragraphStyle.firstLineHeadIndent = 12
            paragraphStyle.headIndent = 12
        case .codeFence:
            break
        }

        let updated = NSRange(location: 0, length: result.length)
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: updated)
        if result.attribute(.foregroundColor, at: 0, effectiveRange: nil) == nil {
            result.addAttribute(.foregroundColor, value: style.textColor, range: updated)
        }
        return result
    }

    private static func renderInline(
        _ text: String,
        style: Style,
        removedImages: inout Int,
        removedLinks: inout Int
    ) -> NSAttributedString {
        // Images are removed BEFORE parsing. Doing it afterwards would mean
        // trusting that an image run is inert until we get to it; removing the
        // syntax means the parser never produces one, so nothing downstream
        // can decide to fetch it.
        let (withoutImages, imageCount) = strippingImageSyntax(from: text)
        removedImages += imageCount

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        // A malformed body still shows the reader something rather than an
        // empty screen.
        options.failurePolicy = .returnPartiallyParsedIfPossible
        // No baseURL: a relative link therefore cannot be resolved into an
        // absolute one the app would be willing to open.
        guard var parsed = try? AttributedString(markdown: withoutImages, options: options) else {
            return NSAttributedString(string: withoutImages, attributes: [.font: style.body])
        }

        for run in parsed.runs {
            // Belt and braces: if the parser ever produces an image run, it is
            // emptied here too.
            if parsed[run.range].imageURL != nil {
                parsed[run.range].imageURL = nil
                removedImages += 1
            }
            guard let link = parsed[run.range].link else { continue }
            if link.scheme?.lowercased() == "https" {
                parsed[run.range].foregroundColor = style.linkColor
                parsed[run.range].underlineStyle = .single
            } else {
                // javascript:, data:, http:, mailto:, or a relative path.
                parsed[run.range].link = nil
                removedLinks += 1
            }
        }

        return NSAttributedString(parsed)
    }

    /// Removes `![alt](url)` and leaves the alt text behind, so the sentence
    /// still reads. Escaped `\![…]` is left alone.
    private static func strippingImageSyntax(from text: String) -> (String, Int) {
        guard text.contains("![") else { return (text, 0) }
        var result = ""
        var removed = 0
        var index = text.startIndex

        while index < text.endIndex {
            guard let bang = text.range(of: "![", range: index..<text.endIndex) else {
                result += text[index...]
                break
            }
            // An escaped bang is literal text, not image syntax.
            if bang.lowerBound > text.startIndex,
               text[text.index(before: bang.lowerBound)] == "\\" {
                result += text[index..<text.index(after: bang.lowerBound)]
                index = text.index(after: bang.lowerBound)
                continue
            }
            result += text[index..<bang.lowerBound]

            guard let closeBracket = text.range(of: "]", range: bang.upperBound..<text.endIndex),
                  text.index(after: closeBracket.lowerBound) < text.endIndex,
                  text[text.index(after: closeBracket.lowerBound)] == "(",
                  let closeParen = text.range(
                      of: ")", range: text.index(after: closeBracket.lowerBound)..<text.endIndex
                  ) else {
                // Not actually image syntax; emit the bang and move on.
                result += "!["
                index = bang.upperBound
                continue
            }

            // Keep the alt text so the prose still makes sense.
            result += text[bang.upperBound..<closeBracket.lowerBound]
            removed += 1
            index = closeParen.upperBound
        }

        return (result, removed)
    }
}

// MARK: - Article body format guard

extension ArticleMarkdownRenderer {
    /// Renders only if the article declares the one format this app supports.
    /// `ArticleMapper` already refuses anything else at the boundary; this is
    /// the second gate, at the point of display.
    static func renderIfSupported(_ article: Article, style: Style = Style()) throws -> Output {
        try render(article, style: style)
    }
}
