import SwiftUI
import MarkdownUI

extension Theme {
    #if os(iOS)
    static let quickStickyNotesIOS = Theme()
        // Text Styles
        .text {
            FontFamily(.system())
            FontSize(.em(1.2))
            ForegroundColor(Color(.label))
        }
        .strong {
            FontWeight(.bold)
            ForegroundColor(Color(.label))
        }
        .emphasis {
            FontStyle(.italic)
        }
        .strikethrough {
            StrikethroughStyle(.single)
            ForegroundColor(Color(.secondaryLabel))
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(1.0))
            BackgroundColor(Color(.systemFill))
            ForegroundColor(Color(.label))
        }
        .link {
            ForegroundColor(Color(.link))
            UnderlineStyle(.single)
        }
        // Block Styles
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(2.4))
                    ForegroundColor(Color(.label))
                }
                .markdownMargin(top: 24, bottom: 16)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.8))
                    ForegroundColor(Color(.label))
                }
                .markdownMargin(top: 20, bottom: 12)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.5))
                    ForegroundColor(Color(.label))
                }
                .markdownMargin(top: 16, bottom: 10)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.3))
                    ForegroundColor(Color(.label))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(1.2))
                    ForegroundColor(Color(.label))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(1.1))
                    ForegroundColor(Color(.label))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .paragraph { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.2))
                    ForegroundColor(Color(.label))
                }
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 16)
        }
        .blockquote { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.regular)
                    FontStyle(.italic)
                    ForegroundColor(Color(.secondaryLabel))
                }
                .padding(.vertical, 8)
                .padding(.leading, 16)
                .background(Color(.systemFill))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 4),
                    alignment: .leading
                )
                .markdownMargin(top: 8, bottom: 8)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(1.0))
                    ForegroundColor(Color(.label))
                }
                .padding()
                .background(Color(.systemFill))
                .cornerRadius(8)
                .markdownMargin(top: 16, bottom: 16)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.25))
        }
        .taskListMarker { configuration in
            ZStack {
                RoundedRectangle(cornerRadius: 4.5)
                    .stroke(configuration.isCompleted ? 
                        Color(.label) :
                        Color(.tertiaryLabel),
                        lineWidth: 1.4
                    )
                    .frame(width: 16, height: 16)
                    .background(
                        RoundedRectangle(cornerRadius: 4.5)
                            .fill(configuration.isCompleted ? 
                                Color(.label) :
                                Color(.systemFill)
                            )
                    )
                
                if configuration.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                        .offset(y: 0.5)
                        .scaleEffect(0.9)
                }
            }
            .padding(.trailing, 3)
            .animation(
                .spring(response: 0.15, dampingFraction: 0.85, blendDuration: 0.1), 
                value: configuration.isCompleted
            )
        }
        .thematicBreak {
            Rectangle()
                .fill(Color(.separator))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .padding(.vertical, 24)
        }
    #endif
    
    static let quickStickyNotes = Theme()
        // Text Styles
        .text { // Base text style
            FontFamily(.system())
            FontSize(.em(1.2))  // Increased from 1.0
            ForegroundColor(.black.opacity(0.8))
        }
        .strong {
            FontWeight(.bold)
            ForegroundColor(.black.opacity(0.9))
        }
        .emphasis {
            FontStyle(.italic)
        }
        .strikethrough {
            StrikethroughStyle(.single)
            ForegroundColor(.black.opacity(0.6))
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(1.0))  // Increased from 0.85
            BackgroundColor(.black.opacity(0.05))
            ForegroundColor(.black.opacity(0.8))
        }
        .link {
            ForegroundColor(.blue)
            UnderlineStyle(.single)
        }
        // Block Styles
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(2.4))  // Increased from 2.0
                    ForegroundColor(.black.opacity(0.9))
                }
                .markdownMargin(top: 24, bottom: 16)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.8))  // Increased from 1.5
                    ForegroundColor(.black.opacity(0.9))
                }
                .markdownMargin(top: 20, bottom: 12)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.5))  // Increased from 1.25
                    ForegroundColor(.black.opacity(0.9))
                }
                .markdownMargin(top: 16, bottom: 10)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.3))  // Increased from 1.1
                    ForegroundColor(.black.opacity(0.9))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(1.2))  // Increased from 1.0
                    ForegroundColor(.black.opacity(0.9))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(1.1))  // Increased from 0.9
                    ForegroundColor(.black.opacity(0.9))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .paragraph { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.2))  // Increased from 1.0
                    ForegroundColor(.black.opacity(0.8))
                }
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 16)
        }
        .blockquote { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.regular)
                    FontStyle(.italic)
                    ForegroundColor(.black.opacity(0.7))
                }
                .padding(.vertical, 8)
                .padding(.leading, 16)
                .background(Color.black.opacity(0.03))
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 4),
                    alignment: .leading
                )
                .markdownMargin(top: 8, bottom: 8)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(1.0))  // Increased from 0.85
                    ForegroundColor(.black.opacity(0.8))
                }
                .padding()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .markdownMargin(top: 16, bottom: 16)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.25))
        }
        .taskListMarker { configuration in
            ZStack {
                // Base checkbox
                RoundedRectangle(cornerRadius: 4.5)
                    .stroke(configuration.isCompleted ? 
                        Color.black.opacity(0.85) : // Strong black for checked
                        Color.black.opacity(0.35), // Subtle for unchecked
                        lineWidth: 1.4
                    )
                    .frame(width: 16, height: 16)
                    .background(
                        RoundedRectangle(cornerRadius: 4.5)
                            .fill(configuration.isCompleted ? 
                                Color.black.opacity(0.85) : // Strong fill when checked
                                Color.black.opacity(0.03) // Very subtle when unchecked
                            )
                    )
                
                if configuration.isCompleted {
                    // Custom checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white) // Crisp white checkmark
                        .offset(y: 0.5)
                        .scaleEffect(0.9) // Slightly smaller for refinement
                }
            }
            .padding(.trailing, 3)
            .animation(
                .spring(response: 0.15, dampingFraction: 0.85, blendDuration: 0.1), 
                value: configuration.isCompleted
            )
        }
        .thematicBreak {
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .padding(.vertical, 24)
        }
} 
