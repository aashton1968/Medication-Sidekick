//
//  HelpView.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2026-01-03.
//

import SwiftUI
import MarkdownUI
import UIKit

import SwiftUI
import MarkdownUI
import UIKit

struct HelpView: View {

    // If you don't use these in this file, remove them (unused env values can generate warnings/errors)
    // @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // If you have your own ThemeManager, keep it. If not, remove these two lines and the toolbar styling.
    @Environment(ThemeManager.self) private var themeManager

    @State private var showTopics = false
    @State private var currentPage: HelpDocumentation.HelpPage

    @State private var markdown: String = ""
    @State private var loadError: String? = nil

    init(initialPage: HelpDocumentation.HelpPage = HelpDocumentation.defaultPage) {
        _currentPage = State(initialValue: initialPage)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                if let loadError {
                    Text("Unable to load help content")
                        .font(.headline)

                    Text(loadError)
                        .font(.subheadline)
                        .foregroundStyle(themeManager.selectedTheme.textSecondary)

                    Divider()
                }

                if !markdown.isEmpty {
                    Markdown(markdown)
                        .markdownImageProvider(.asset)
                } else {
                    ProgressView()
                }
            }
            .padding()
        }
        .task {
            let url = currentPage.markdownURL
            
        }
        
        .navigationBarTitleDisplayMode(.inline)
        
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(currentPage.title.isEmpty ? "Help" : currentPage.title)
                    .font(.headline)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTopics = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("Browse help topics")
            }
        }
        .task(id: currentPageTaskID) {
            await loadMarkdownForCurrentPage()
        }
        .sheet(isPresented: $showTopics) {
            HelpListView { selected in
                currentPage = selected
                showTopics = false
            }
            .environment(themeManager)
        }
    }

    private var currentPageTaskID: String {
        "\(currentPage.title)|\(currentPage.markdownURL.absoluteString)"
    }

    // MARK: - Load

    @MainActor
    private func loadMarkdownForCurrentPage() async {
        loadError = nil
        let url = currentPage.markdownURL
        do {
            let raw = try await readBundleFile(at: url)
            markdown = sanitizeMissingAssetImages(in: raw)
        } catch {
            markdown = "❌ Failed to load help content."
            loadError = presentableError(error, url: url)
        }
    }

    nonisolated private func readBundleFile(at url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw HelpLoadError.invalidEncoding
        }
        return string
    }

    private func presentableError(_ error: Error, url: URL) -> String {
        if let helpError = error as? HelpLoadError {
            switch helpError {
            case .invalidEncoding:
                return "The help file could not be decoded as UTF-8.\n\nFile: \(url.lastPathComponent)"
            }
        }

        let ns = error as NSError
        return """
        \(ns.localizedDescription)

        File: \(url.lastPathComponent)
        Domain: \(ns.domain)
        Code: \(ns.code)
        """
    }

    enum HelpLoadError: Error {
        case invalidEncoding
    }

    // MARK: - Prevent missing-asset crashes

    /// MarkdownUI's `.asset` image provider can crash on device if an image name doesn't exist.
    /// This strips or replaces those image references BEFORE MarkdownUI sees them.
    private func sanitizeMissingAssetImages(in text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var output: [String] = []
        output.reserveCapacity(lines.count)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Match markdown image: ![alt](NAME)
            // We only handle the simple case you are generating: ![Image](Foo)
            if trimmed.hasPrefix("!["),
               let open = trimmed.firstIndex(of: "("),
               let close = trimmed.firstIndex(of: ")"),
               open < close {

                let name = String(trimmed[trimmed.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)

                // If the image doesn't exist in the asset catalog, replace with safe text.
                if UIImage(named: name) == nil {
                    output.append("_Image not available: \(name)_")
                    continue
                }
            }

            output.append(line)
        }

        return output.joined(separator: "\n")
    }
}

#Preview {
    let themeManager = ThemeManager()

    NavPreview {
        HelpView()
    }
    .environment(themeManager)
}
