# Instrukcja: notaryzacja i AltStore PAL

Stan źródeł: 2026-09-16. Żadnego z poniższych kroków jeszcze nie wykonano. Kroki na kontach Apple i AltStore wykonuje użytkownik. Przed każdym wydaniem sprawdź, czy warunki i opłaty są aktualne.

Źródła: [Distribute with AltStore PAL](https://faq.altstore.io/developers/distribute-with-altstore-pal), [Make a Source](https://faq.altstore.io/developers/make-a-source), [App Guidelines AltStore](https://faq.altstore.io/developers/app-guidelines), [Apple: zmiany dla aplikacji w UE](https://developer.apple.com/support/dma-and-apps-in-the-eu/), [Submit for Notarization](https://developer.apple.com/help/app-store-connect/distributing-apps-in-the-european-union/submit-for-notarization/).

## 0. Warunki wstępne w kodzie

- [ ] Bramki G2 i G3 z [01-PLAN-WYDANIA.md](01-PLAN-WYDANIA.md).
- [x] Ostateczny Bundle ID `pl.mintstudio.findhubandroid` (2026-09-16).
- [x] `SOURCE_CODE_URL` = https://github.com/darthkubox/FindHub-Android. [ ] Wersja w repozytorium ma tag równy `MARKETING_VERSION`.
- [ ] `MARKETING_VERSION` i `CURRENT_PROJECT_VERSION` podbite.
- [ ] `bash Scripts/check_local.sh --build` i XCTest bez błędów; wynik zapisany w `docs/evidence/`.

## 1. Konto Apple Developer (użytkownik)

- [ ] Aktywne płatne członkostwo (ok. 99 USD rocznie).
- [ ] Informacja o przedsiębiorcy (DSA) w App Store Connect, zgodna z rzeczywistym statusem.

## 2. Warunki dystrybucji alternatywnej (użytkownik)

- [ ] W App Store Connect zaakceptować **Alternative Terms Addendum for Apps in the EU**. Wymaga tego dystrybucja przez alternatywny sklep.
- [ ] Sprawdzić aktualny model opłat (Core Technology Commission / Fee) dla aplikacji bezpłatnej i zapisać wynik z datą w `docs/07-STAN-I-DOWODY.md`.

## 3. Rejestracja w AltStore PAL (użytkownik)

- [ ] Zarejestrować Developer ID w AltStore PAL (według ich FAQ; odbywa się przez REST API AltStore).
- [ ] Otrzymany token wkleić w App Store Connect: **Users and Access → Integrations → Marketplace**.
- [ ] Wskazać aplikację do dystrybucji w AltStore PAL i włączyć automatyczne przetwarzanie.

## 4. Rekord aplikacji i notaryzacja

- [ ] W App Store Connect utworzyć rekord aplikacji z ostatecznym Bundle ID. Przy wersji wybrać ocenę według **Notarization Review Guidelines** (dystrybucja wyłącznie alternatywna).
- [ ] Przed wysyłką przejrzeć [wytyczne](https://developer.apple.com/app-store/review/guidelines/) z filtrem **Highlight Notarization Review Guidelines Only**; zapisać listę obowiązujących punktów w `docs/evidence/notarization-guidelines-<data>.txt`.
- [ ] Xcode: `App/FindHub Android.xcodeproj`, schemat `FindHub Android`, urządzenie *Any iOS Device* → **Product → Archive** (automatyczny podpis na koncie z kroku 1; nie używać `CODE_SIGNING_ALLOWED=NO`).
- [ ] Organizer → **Distribute App → App Store Connect** → upload.
- [ ] W polu **App Review Information → Notes** wkleić [NOTARIZATION-REVIEW-NOTES.md](templates/NOTARIZATION-REVIEW-NOTES.md). Recenzent sprawdza aplikację w trybie demo; konto Google i PIN telefonu z Androidem nie są potrzebne.
- [ ] Uzupełnić wymagane dane wersji (opis, kontakt, polityka prywatności, zrzuty, jeśli wymagane) według szablonu [METADANE-SKLEPU.md](templates/METADANE-SKLEPU.md).
- [ ] Wysłać do notaryzacji. Zapisać wynik i ewentualne uwagi Apple.

Przy odmowie: zapisać punkt wytycznych i treść, poprawić aplikację lub opis, nie ukrywać funkcji.

## 5. Pakiet ADP i hosting

- [ ] Po notaryzacji pobrać **Alternative Distribution Package (ADP)** przez App Store Connect API.
- [ ] Wgrać cały pakiet na serwer HTTPS **bez modyfikowania `manifest.json`**. Pliki można umieścić np. w GitHub Releases; wtedy w źródle trzeba podać `assetURLs`.

## 6. Źródło AltStore

- [ ] Uzupełnić [templates/altstore-source.json](templates/altstore-source.json): `marketplaceID` to Apple ID aplikacji z App Store Connect; `downloadURL` wskazuje `manifest.json` ADP albo katalog ADP; `size` w bajtach; `date` w ISO 8601.
- [ ] Opublikować plik JSON pod stałym adresem HTTPS (np. GitHub Pages).
- [ ] Opcjonalnie: federacja źródła w katalogu alt.store.

## 7. Test instalacji i publikacja

- [ ] Na iPhonie z regionem UE zainstalować AltStore PAL, dodać źródło, zainstalować FindHub Android.
- [ ] Sprawdzić: logowanie, listę tagów, lokalizację, Ustawienia → Licencje i kod źródłowy (link działa), usuwanie danych konta.
- [ ] Zapisać wersję, build, datę i wynik w `docs/07-STAN-I-DOWODY.md`.

## Aktualizacje

Każda nowa wersja: podbić build → testy → tag Git w publicznym repozytorium → archiwum → notaryzacja → nowy ADP → dopisanie wersji na początku `versions` w źródle. Stary ADP zostaje dostępny, dopóki użytkownicy go potrzebują.

## Awaria integracji Google

Gdy Google zmieni protokół: opublikować wpis w `news` źródła i na stronie projektu. Nie obiecywać terminu naprawy. Jeśli naprawa nie jest możliwa, usunąć aplikację ze źródła i to opisać.
