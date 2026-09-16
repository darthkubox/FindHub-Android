// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Bundled legal documents. The same Markdown files are published in the
/// repository, so the app and the public links always show identical text.
enum LegalDocument: String, CaseIterable, Identifiable {
    case privacy = "polityka-prywatnosci"
    case terms = "warunki-korzystania"

    /// Bump when either document changes in a way that needs renewed acceptance.
    static let currentVersion = 1

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Polityka prywatności"
        case .terms: return "Warunki korzystania"
        }
    }

    var publicURL: URL {
        URL(string: "https://github.com/darthkubox/FindHub-Android/blob/main/App/Resources/Legal/\(rawValue).md")!
    }

    var text: String {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Nie znaleziono dokumentu w aplikacji. Aktualna wersja: \(publicURL.absoluteString)"
        }
        return text
    }
}

/// Acceptance of the current terms and privacy policy, stored per install.
enum LegalConsent {
    private static let key = "legal_accepted_version"

    static var isAccepted: Bool {
        UserDefaults.standard.integer(forKey: key) >= LegalDocument.currentVersion
    }

    static func accept() {
        UserDefaults.standard.set(LegalDocument.currentVersion, forKey: key)
    }
}

/// Renders the small Markdown subset used by the legal documents: `#`/`##`
/// headings, `- ` bullets and paragraphs with inline emphasis and links.
struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.colorScheme) private var scheme

    private enum Block: Hashable {
        case title(String), heading(String), bullet(String), paragraph(String)
    }

    private var blocks: [Block] {
        document.text.components(separatedBy: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return nil }
            if line.hasPrefix("## ") { return .heading(String(line.dropFirst(3))) }
            if line.hasPrefix("# ") { return .title(String(line.dropFirst(2))) }
            if line.hasPrefix("- ") { return .bullet(String(line.dropFirst(2))) }
            return .paragraph(line)
        }
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        // Bare URLs and e-mail addresses become tappable autolinks.
        let linked = text.replacingOccurrences(of: #"(https://[^\s)]+[^\s).,;])"#, with: "<$1>", options: .regularExpression)
            .replacingOccurrences(of: #"\b([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})\b"#, with: "[$1](mailto:$1)", options: .regularExpression)
        return Text((try? AttributedString(markdown: linked, options: options)) ?? AttributedString(text))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .title(let text):
                        Text(text).font(.title2.bold()).foregroundStyle(M3.onSurface(scheme))
                    case .heading(let text):
                        Text(text).font(.headline).foregroundStyle(M3.onSurface(scheme)).padding(.top, 8)
                    case .bullet(let text):
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").foregroundStyle(M3.primary(scheme))
                            inline(text)
                        }
                        .font(.subheadline).foregroundStyle(M3.onSurface(scheme))
                    case .paragraph(let text):
                        inline(text).font(.subheadline).foregroundStyle(M3.onSurface(scheme))
                    }
                }
                Link("Wersja online", destination: document.publicURL)
                    .font(.footnote).padding(.top, 12)
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(M3.background(scheme).ignoresSafeArea())
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
