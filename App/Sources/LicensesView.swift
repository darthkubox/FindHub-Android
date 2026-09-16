// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Licences of the app (GPLv3) and bundled third-party components, plus the
/// public source-code location required for GPL distribution.
struct LicensesView: View {
    @Environment(\.colorScheme) private var scheme

    /// Publisher shown in Settings, from the `PUBLISHER_NAME` build setting.
    static var publisher: String {
        (Bundle.main.object(forInfoDictionaryKey: "FHAPublisher") as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "—"
    }

    /// Support e-mail as a `mailto:` link, from the `PUBLISHER_CONTACT` build setting.
    static var contactURL: URL? {
        guard let mail = Bundle.main.object(forInfoDictionaryKey: "FHAPublisherContact") as? String,
              mail.contains("@") else { return nil }
        return URL(string: "mailto:\(mail)")
    }

    /// Filled from the `SOURCE_CODE_URL` build setting.
    static var sourceCodeURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "FHASourceCodeURL") as? String,
              let url = URL(string: raw.trimmingCharacters(in: .whitespaces)),
              url.scheme == "https" else { return nil }
        return url
    }

    var body: some View {
        List {
            Section {
                Text("FindHub Android to niezależna, nieoficjalna aplikacja wydawana przez mintstudio. Nie jest powiązana z Google, Motorola ani Apple. Find Hub i Android są znakami towarowymi Google LLC; nazwy służą wyłącznie opisaniu zgodności.")
                    .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
            }
            Section("Kod źródłowy") {
                if let url = Self.sourceCodeURL {
                    Link(destination: url) {
                        Label(url.absoluteString, systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } else {
                    Text("Brak adresu repozytorium w tej kompilacji.")
                        .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                }
                Text("Aplikację rozpowszechniamy na licencji GNU GPL v3.0 lub nowszej. Korzysta z pracy autorów GoogleFindMyTools, firebase-messaging, gpsoauth, http_ece, micro-ecc, Chromium i SwiftProtobuf.")
                    .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
            }
            Section("Licencje") {
                NavigationLink("Komponenty, źródła i podziękowania") { LicenseTextView(title: "Komponenty", resource: "ACKNOWLEDGEMENTS") }
                NavigationLink("GNU General Public License v3.0") { LicenseTextView(title: "GPL v3.0", resource: "GPL-3.0") }
            }
        }
        .navigationTitle("Licencje i kod źródłowy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseTextView: View {
    let title: String
    let resource: String

    private var text: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Nie znaleziono tekstu licencji w aplikacji."
        }
        return text
    }

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
