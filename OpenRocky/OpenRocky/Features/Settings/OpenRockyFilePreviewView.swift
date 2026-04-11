//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

@_exported import struct MarkdownView.MarkdownView
import PDFKit
import SwiftUI

private typealias MarkdownContentView = MarkdownView

struct OpenRockyFilePreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            previewContent
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            shareItem = ShareItem(url: url)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(item: $shareItem) { item in
                    ActivityView(activityItems: [item.url])
                        .presentationDetents([.medium, .large])
                }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch fileKind {
        case .image:
            ImagePreview(url: url)
        case .pdf:
            PDFPreview(url: url)
        case .markdown:
            MarkdownPreview(url: url)
        case .text:
            TextPreview(url: url)
        }
    }

    private enum FileKind {
        case image, pdf, markdown, text
    }

    private var fileKind: FileKind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "bmp", "tiff":
            return .image
        case "pdf":
            return .pdf
        case "md", "markdown":
            return .markdown
        default:
            return .text
        }
    }

    /// Check if a file can be previewed inline.
    static func canPreview(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let textExtensions: Set = [
            "txt", "md", "markdown", "json", "csv", "log",
            "py", "swift", "js", "ts", "html", "css", "xml", "yaml", "yml",
            "sh", "bash", "zsh", "conf", "ini", "toml", "env",
            "c", "cpp", "h", "m", "rs", "go", "java", "kt", "rb"
        ]
        let imageExtensions: Set = ["png", "jpg", "jpeg", "gif", "webp", "heic", "bmp", "tiff"]
        return textExtensions.contains(ext) || imageExtensions.contains(ext) || ext == "pdf"
    }
}

// MARK: - Image Preview

private struct ImagePreview: View {
    let url: URL

    var body: some View {
        if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }
            .background(Color(uiColor: .secondarySystemBackground))
        } else {
            Text("Unable to load image")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - PDF Preview

private struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Text Preview

private struct TextPreview: View {
    let url: URL
    @State private var content: String = ""

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 13, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .onAppear {
            content = (try? String(contentsOf: url, encoding: .utf8)) ?? "Unable to read file."
        }
    }
}

// MARK: - Markdown Preview

private struct MarkdownPreview: View {
    let url: URL
    @State private var content: String = ""

    var body: some View {
        ScrollView {
            MarkdownContentView(content)
                .padding()
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .onAppear {
            content = (try? String(contentsOf: url, encoding: .utf8)) ?? "Unable to read file."
        }
    }
}
