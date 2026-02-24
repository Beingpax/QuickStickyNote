import SwiftUI
import WebKit

struct CodeMirrorEditorView: NSViewRepresentable {
    @Binding var text: String
    var backgroundColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "textChanged")
        config.userContentController.add(context.coordinator, name: "editorReady")
        config.userContentController.add(context.coordinator, name: "checkboxToggled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Transparent background so material / note color shows through
        webView.setValue(false, forKey: "drawsBackground")

        // Load editor.html from bundle
        if let url = Bundle.main.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        // Sync text if changed externally (not from JS)
        if !coordinator.isUpdatingFromJS && coordinator.isEditorReady {
            if text != coordinator.lastTextFromJS {
                let escaped = escapeForJS(text)
                webView.evaluateJavaScript("window.cmSetText(`\(escaped)`)")
                coordinator.lastTextFromJS = text
            }
        }

        // Sync background color
        let bgHex = backgroundColor.cssString
        if bgHex != coordinator.lastBgColor {
            coordinator.lastBgColor = bgHex
            if coordinator.isEditorReady {
                webView.evaluateJavaScript("window.cmSetTheme('\(bgHex)')")
            }
        }
    }

    private func escapeForJS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "`", with: "\\`")
         .replacingOccurrences(of: "$", with: "\\$")
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: CodeMirrorEditorView
        weak var webView: WKWebView?

        var isEditorReady = false
        var isUpdatingFromJS = false
        var lastTextFromJS: String = ""
        var lastBgColor: String = ""

        init(_ parent: CodeMirrorEditorView) {
            self.parent = parent
            self.lastTextFromJS = parent.text
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "editorReady":
                isEditorReady = true

                let escaped = parent.escapeForJS(parent.text)
                webView?.evaluateJavaScript("window.cmSetText(`\(escaped)`)")
                lastTextFromJS = parent.text

                let bgHex = parent.backgroundColor.cssString
                lastBgColor = bgHex
                webView?.evaluateJavaScript("window.cmSetTheme('\(bgHex)')")

                webView?.evaluateJavaScript("window.cmFocus()")

            case "textChanged":
                guard let content = message.body as? String else { return }
                isUpdatingFromJS = true
                lastTextFromJS = content
                parent.text = content
                DispatchQueue.main.async {
                    self.isUpdatingFromJS = false
                }

            case "checkboxToggled":
                break

            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // editor.js sends editorReady on load
        }
    }
}

// MARK: - NSColor CSS helper

private extension NSColor {
    var cssString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "transparent" }
        let a = rgb.alphaComponent
        if a < 0.01 { return "transparent" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        if a < 1.0 {
            return String(format: "rgba(%d,%d,%d,%.2f)", r, g, b, a)
        }
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
