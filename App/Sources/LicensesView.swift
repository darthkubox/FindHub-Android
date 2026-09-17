// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A project Tagpin builds on: where its code came from, in which
/// version, and under which licence. Kept in sync with ACKNOWLEDGEMENTS-*.txt,
/// NOTICE and the README tables.
struct UpstreamProject: Identifiable {
    let name: String
    let authors: String
    let license: String
    let version: String
    let usage: LocalizedStringResource
    let url: URL
    var id: String { name }

    static let all: [UpstreamProject] = [
        .init(name: "GoogleFindMyTools", authors: "Leon Böttger (SEEMOO, TU Darmstadt)", license: "GPL-3.0",
              version: "d46e952 (2026-05-05)",
              usage: "Protokół Find Hub: logowanie, lista urządzeń, klucze i odszyfrowanie raportów",
              url: URL(string: "https://github.com/leonboe1/GoogleFindMyTools")!),
        .init(name: "firebase-messaging", authors: "Matthieu Lemoine, Steven Beth", license: "MIT",
              version: "GoogleFindMyTools d46e952",
              usage: "Rejestracja powiadomień push i połączenie MCS",
              url: URL(string: "https://github.com/sdb9696/firebase-messaging")!),
        .init(name: "gpsoauth", authors: "Simon Weber", license: "MIT", version: "2.0.0",
              usage: "Wymiana tokenów konta Google",
              url: URL(string: "https://github.com/simon-weber/gpsoauth")!),
        .init(name: "encrypted-content-encoding (http_ece)", authors: "Martin Thomson", license: "MIT", version: "1.2.1",
              usage: "Odszyfrowanie wiadomości push",
              url: URL(string: "https://github.com/web-push-libs/encrypted-content-encoding")!),
        .init(name: "micro-ecc", authors: "Kenneth MacKay", license: "BSD-2-Clause", version: "541b3a7 (2024-11-14)",
              usage: "Kryptografia krzywych eliptycznych SECP160r1",
              url: URL(string: "https://github.com/kmackay/micro-ecc")!),
        .init(name: "Chromium", authors: "The Chromium Authors", license: "BSD-3-Clause", version: "google_apis/gcm/protocol",
              usage: "Definicje protokołu checkin i MCS",
              url: URL(string: "https://chromium.googlesource.com/chromium/src/+/main/google_apis/gcm/protocol/")!),
        .init(name: "SwiftProtobuf", authors: "Apple Inc.", license: "Apache-2.0", version: "1.38.1",
              usage: "Obsługa formatu Protocol Buffers",
              url: URL(string: "https://github.com/apple/swift-protobuf")!),
    ]

    /// Specifications and references the implementation follows; no code copied.
    static let references: [(title: LocalizedStringResource, url: URL)] = [
        ("Specyfikacja akcesoriów sieci Find Hub (Google)", URL(string: "https://developers.google.com/nearby/fast-pair/specifications/extensions/fmdn")!),
        ("IETF DULT — wykrywanie niechcianych lokalizatorów", URL(string: "https://datatracker.ietf.org/wg/dult/about/")!),
        ("Szyfrowanie wiadomości Web Push (IETF)", URL(string: "https://datatracker.ietf.org/doc/html/draft-ietf-webpush-encryption-04")!),
        ("Tryb szyfrowania EAX (Bellare, Rogaway, Wagner)", URL(string: "https://www.cs.ucdavis.edu/~rogaway/papers/eax.pdf")!),
        ("Material Design 3", URL(string: "https://m3.material.io")!),
    ]
}

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
            Group {
            Section {
                Text("Tagpin to niezależna, nieoficjalna aplikacja wydawana przez mintstudio. Nie jest powiązana z Google, Motorola ani Apple. Find Hub i Android są znakami towarowymi Google LLC; nazwy służą wyłącznie opisaniu zgodności.")
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
            Section {
                ForEach(UpstreamProject.all) { project in
                    Link(destination: project.url) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(verbatim: project.name).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(M3.onSurface(scheme))
                                Spacer()
                                Image(systemName: "arrow.up.right.square").foregroundStyle(M3.primary(scheme))
                            }
                            Text(project.usage).font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                            Text(verbatim: "\(project.authors) · \(project.license) · \(project.version)")
                                .font(.caption2).foregroundStyle(M3.onSurfaceVariant(scheme))
                        }
                        .padding(.vertical, 6)
                    }
                    .accessibilityHint(Text(verbatim: project.url.absoluteString))
                }
            } header: {
                Text("Projekty, na których opiera się aplikacja")
            } footer: {
                Text("Dziękujemy autorom tych projektów. Linki prowadzą do ich oryginalnych repozytoriów.")
            }
            Section("Specyfikacje i materiały referencyjne") {
                ForEach(UpstreamProject.references, id: \.url) { reference in
                    Link(destination: reference.url) {
                        Label { Text(reference.title) } icon: { Image(systemName: "book") }
                            .font(.subheadline)
                    }
                }
            }
            Section("Licencje") {
                NavigationLink("Komponenty, źródła i podziękowania") {
                    LicenseTextView(title: "Komponenty", resource: "ACKNOWLEDGEMENTS-\(LegalDocument.language)")
                }
                NavigationLink("GNU General Public License v3.0") { LicenseTextView(title: "GPL v3.0", resource: "GPL-3.0") }
            }
            }
            .listRowBackground(M3.background(scheme))
        }
        .m3SheetList(scheme)
        .navigationTitle("Licencje i kod źródłowy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseTextView: View {
    let title: LocalizedStringKey
    let resource: String

    private var text: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return String(localized: "Nie znaleziono tekstu licencji w aplikacji.")
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
