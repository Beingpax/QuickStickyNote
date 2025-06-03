import AppKit
import Foundation

class MarkdownInlineStyleFormatter {

    static func applyInlineFormatting(to textStorage: NSTextStorage, baseFont: NSFont, syntaxColor: NSColor, defaultTextColor: NSColor) {
        // Ensure that an initial pass of default styling (especially font) is done before applying bold/italic.
        // This is typically handled by applyAllFormatting before this method is called.

        // Order matters: apply bold first, then italic to allow nesting like **_bold italic_**.
        // However, for simplicity and to avoid complex regex lookaheads/lookbehinds for overlapping patterns,
        // we'll process them based on the length of the markers (e.g., ** before *).
        // A more robust solution would involve a proper parser, but regex can work for common cases.

        // Patterns:
        // Bold: **text** or __text__
        // Italic: *text* or _text_

        // We'll apply styling in passes. It's important that attributes are applied correctly
        // and that later passes don't incorrectly override earlier ones for syntax highlighting.

        let fullRange = NSRange(location: 0, length: textStorage.length)
        let string = textStorage.string as NSString

        // Apply Bold (**)
        applyStyle(
            to: textStorage,
            string: string,
            pattern: "\\*\\*([^\\*\\s](?:[^\\*]*[^\\*\\s])?)\\*\\*", // **text**
            syntaxLength: 2,
            baseFont: baseFont,
            trait: .boldFontMask,
            syntaxColor: syntaxColor,
            defaultTextColor: defaultTextColor
        )

        // Apply Bold (__)
        applyStyle(
            to: textStorage,
            string: string,
            pattern: "__([^__\\s](?:[^_]*[^__\\s])?)__", // __text__
            syntaxLength: 2,
            baseFont: baseFont,
            trait: .boldFontMask,
            syntaxColor: syntaxColor,
            defaultTextColor: defaultTextColor
        )
        
        // Apply Italic (*)
        // Need to be careful not to match parts of **
        // A simple way is to ensure the regex for * does not match if it's part of **
        // This is complex with pure regex. A common approach is to replace styled parts or use a parser.
        // For now, we'll use a regex that tries to avoid **.
        // A more robust approach would be to process ** first, then process * on remaining unstyled parts.
        // The current regex for * might still pick up * within already bolded ****text**** if not careful.
        // However, NSTextStorage applies attributes, so re-applying italic to a bolded section that happens
        // to have * inside should be okay if the font manager handles combining traits.
        
        applyStyle(
            to: textStorage,
            string: string,
            // Matches *text* but not **text** or * text * or *text * or * text*
            // Breakdown:
            // (?<!\\*) : Negative lookbehind, ensures not preceded by another * (to avoid matching middle of ***)
            // \\*       : Literal *
            // ([^\\*\\s] : Content starts with non-* and non-whitespace
            // (?:[^\\*]*[^\\*\\s])? : Content can have other non-* chars, ending with non-* and non-whitespace
            // )          : End content group
            // \\*       : Literal *
            // (?!\\*)  : Negative lookahead, ensures not followed by another * (to avoid matching middle of ***)
            pattern: "(?<!\\*)\\*([^\\*\\s](?:[^\\*]*[^\\*\\s])?)\\*(?!\\*)", // *text*
            syntaxLength: 1,
            baseFont: baseFont,
            trait: .italicFontMask,
            syntaxColor: syntaxColor,
            defaultTextColor: defaultTextColor
        )

        // Apply Italic (_)
        // Similar care for __
        applyStyle(
            to: textStorage,
            string: string,
            pattern: "(?<!_)_([^\\_\\s](?:[^_]*[^\\_\\s])?)_(?!_)", // _text_
            syntaxLength: 1,
            baseFont: baseFont,
            trait: .italicFontMask,
            syntaxColor: syntaxColor,
            defaultTextColor: defaultTextColor
        )
    }

    private static func applyStyle(
        to textStorage: NSTextStorage,
        string: NSString,
        pattern: String,
        syntaxLength: Int,
        baseFont: NSFont,
        trait: NSFontTraitMask,
        syntaxColor: NSColor,
        defaultTextColor: NSColor
    ) {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))

            // Iterate backwards to avoid range issues when modifying attributed string by hiding syntax
            for match in matches.reversed() {
                let overallMatchRange = match.range
                
                // Content is in group 1
                guard match.numberOfRanges > 1 else { continue }
                let contentRange = match.range(at: 1)

                // Apply font trait to the content
                if contentRange.location != NSNotFound && contentRange.length > 0 {
                    textStorage.enumerateAttributes(in: contentRange, options: []) { attrs, range, _ in
                        let currentFont = attrs[.font] as? NSFont ?? baseFont
                        let newFont = NSFontManager.shared.convert(currentFont, toHaveTrait: trait)
                        textStorage.addAttribute(.font, value: newFont, range: range)
                        // Ensure default text color for content, in case syntaxColor was broadly applied
                        textStorage.addAttribute(.foregroundColor, value: defaultTextColor, range: range)
                    }
                }

                // Style leading syntax markers
                let leadingSyntaxRange = NSRange(location: overallMatchRange.location, length: syntaxLength)
                if leadingSyntaxRange.location != NSNotFound {
                     textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: leadingSyntaxRange)
                     // textStorage.addAttribute(.font, value: NSFont(descriptor: baseFont.fontDescriptor, size: baseFont.pointSize * 0.9) ?? baseFont, range: leadingSyntaxRange)
                }

                // Style trailing syntax markers
                let trailingSyntaxRange = NSRange(location: overallMatchRange.location + overallMatchRange.length - syntaxLength, length: syntaxLength)
                if trailingSyntaxRange.location != NSNotFound {
                    textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: trailingSyntaxRange)
                    // textStorage.addAttribute(.font, value: NSFont(descriptor: baseFont.fontDescriptor, size: baseFont.pointSize * 0.9) ?? baseFont, range: trailingSyntaxRange)
                }
            }
        } catch {
            print("Error creating regex: \(error.localizedDescription)")
        }
    }
} 