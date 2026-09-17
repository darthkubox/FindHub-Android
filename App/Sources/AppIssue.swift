// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import CoreBluetooth

/// A problem (or a short confirmation) worth showing on the signed-in screens,
/// translated from low-level errors into what happened and what the user can do.
struct AppIssue: Identifiable, Equatable {
    enum Kind: Equatable {
        case offline, googleUnreachable, rateLimited, sessionExpired
        case bluetoothOff, bluetoothDenied, noNearbyTracker, ringUnsupported
        case failed(Context)
        case ringSent, demoRing
    }

    /// What the user was doing when it happened; decides the retry.
    enum Context: Equatable { case devices, locations, unlock, ring }

    enum Action: Equatable { case retry, signInAgain, openSettings, unlockKeys, none }

    let kind: Kind
    let context: Context
    let title: String
    let message: String
    let action: Action

    var id: String { "\(kind)-\(context)" }
    /// Confirmations disappear on their own and use a positive style.
    var isConfirmation: Bool { kind == .ringSent || kind == .demoRing }

    static func ringSent() -> AppIssue {
        AppIssue(kind: .ringSent, context: .ring,
                 title: String(localized: "Wysłano dźwięk do najbliższego taga"),
                 message: String(localized: "Jeśli nic nie słychać, podejdź bliżej i spróbuj ponownie."),
                 action: .none)
    }

    static func demoRing() -> AppIssue {
        AppIssue(kind: .demoRing, context: .ring,
                 title: String(localized: "Tryb demo: dźwięk nie został wysłany"),
                 message: String(localized: "W trybie demonstracyjnym aplikacja nie łączy się z tagami. Zaloguj się, aby dzwonić do prawdziwych urządzeń."),
                 action: .none)
    }

    static func offline(_ context: Context = .devices) -> AppIssue {
        AppIssue(kind: .offline, context: context,
                 title: String(localized: "Brak połączenia z internetem"),
                 message: String(localized: "Pokazuję ostatnie znane pozycje. Odświeżę je, gdy połączenie wróci."),
                 action: .retry)
    }

    /// Maps an error thrown by Google, push, crypto or Bluetooth code to a message.
    static func from(_ error: Error, context: Context,
                     bluetoothAuthorization: CBManagerAuthorization = CBManager.authorization) -> AppIssue {
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                return offline(context)
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .secureConnectionFailed:
                return unreachable(context)
            default: break
            }
        }
        if let nova = error as? NovaError, case .http(let code) = nova { return http(code, context: context) }
        if let auth = error as? GoogleAuthError {
            switch auth {
            case .http(let code): return http(code, context: context)
            case .missingField, .badResponse: return sessionExpired(context)
            }
        }
        if error is McsError { return unreachable(context) }
        if let ble = error as? BleError {
            switch ble {
            case .unavailable:
                if bluetoothAuthorization == .denied || bluetoothAuthorization == .restricted {
                    return AppIssue(kind: .bluetoothDenied, context: context,
                                    title: String(localized: "Brak dostępu do Bluetooth"),
                                    message: String(localized: "Zezwól aplikacji na korzystanie z Bluetooth w Ustawieniach iPhone’a."),
                                    action: .openSettings)
                }
                return AppIssue(kind: .bluetoothOff, context: context,
                                title: String(localized: "Bluetooth jest wyłączony"),
                                message: String(localized: "Włącz Bluetooth w Centrum sterowania i spróbuj ponownie."),
                                action: .retry)
            case .timeout:
                return AppIssue(kind: .noNearbyTracker, context: context,
                                title: String(localized: "Nie znaleziono taga w pobliżu"),
                                message: String(localized: "Podejdź bliżej i upewnij się, że tag jest włączony."),
                                action: .retry)
            case .notFound:
                return AppIssue(kind: .ringUnsupported, context: context,
                                title: String(localized: "Ten tag nie obsługuje dzwonienia"),
                                message: String(localized: "Najbliższy tag nie udostępnia dźwięku przez Bluetooth."),
                                action: .none)
            }
        }
        return AppIssue(kind: .failed(context), context: context, title: failureTitle(context),
                        message: error.localizedDescription,
                        action: context == .unlock ? .unlockKeys : .retry)
    }

    private static func http(_ code: Int, context: Context) -> AppIssue {
        switch code {
        case 401, 403: return sessionExpired(context)
        case 429:
            return AppIssue(kind: .rateLimited, context: context,
                            title: String(localized: "Google ogranicza liczbę zapytań"),
                            message: String(localized: "Odczekaj kilka minut i spróbuj ponownie."),
                            action: .retry)
        default: return unreachable(context)
        }
    }

    private static func unreachable(_ context: Context) -> AppIssue {
        AppIssue(kind: .googleUnreachable, context: context,
                 title: String(localized: "Google nie odpowiada"),
                 message: String(localized: "Nie udało się połączyć z usługą Find Hub. Spróbuj ponownie za chwilę."),
                 action: .retry)
    }

    private static func sessionExpired(_ context: Context) -> AppIssue {
        AppIssue(kind: .sessionExpired, context: context,
                 title: String(localized: "Sesja Google wygasła"),
                 message: String(localized: "Zaloguj się ponownie, aby odświeżyć dostęp do urządzeń."),
                 action: .signInAgain)
    }

    private static func failureTitle(_ context: Context) -> String {
        switch context {
        case .devices: return String(localized: "Nie udało się pobrać urządzeń")
        case .locations: return String(localized: "Nie udało się pobrać lokalizacji")
        case .unlock: return String(localized: "Nie udało się odblokować kluczy")
        case .ring: return String(localized: "Nie udało się zadzwonić")
        }
    }
}

/// Card for `AppIssue` inside the drawers: what happened, the one useful action
/// and a way to dismiss it.
struct IssueBanner: View {
    let issue: AppIssue
    let onAction: () -> Void
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var icon: String {
        switch issue.kind {
        case .offline: return "wifi.slash"
        case .googleUnreachable, .rateLimited: return "icloud.slash"
        case .sessionExpired: return "person.crop.circle.badge.exclamationmark"
        case .bluetoothOff, .bluetoothDenied: return "antenna.radiowaves.left.and.right.slash"
        case .noNearbyTracker, .ringUnsupported: return "bell.slash"
        case .failed: return "exclamationmark.triangle"
        case .ringSent: return "checkmark.circle.fill"
        case .demoRing: return "play.rectangle.fill"
        }
    }

    private var tint: Color { issue.isConfirmation ? .green : .orange }

    private var actionTitle: LocalizedStringKey? {
        switch issue.action {
        case .retry: return "Spróbuj ponownie"
        case .signInAgain: return "Zaloguj się ponownie"
        case .openSettings: return "Otwórz ustawienia"
        case .unlockKeys: return "Odblokuj klucze E2EE"
        case .none: return nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(issue.title).font(.subheadline.weight(.semibold)).foregroundStyle(M3.onSurface(scheme))
                Text(issue.message).font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle {
                    Button(actionTitle, action: onAction)
                        .buttonStyle(M3TonalButtonStyle())
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(M3.onSurfaceVariant(scheme))
                    .frame(width: 28, height: 28)
                    .background(M3.surfaceVariant(scheme).opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Zamknij"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(M3.background(scheme), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.35), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .contain)
    }
}
