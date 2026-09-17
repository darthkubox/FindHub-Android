# Stan przygotowania i rejestr dowodów

Data utworzenia: 2026-09-16.

## Wykonane przy utworzeniu kopii

| Kontrola | Wynik | Dowód |
|---|---|---|
| Osobny katalog i kopia kodu | WYKONANE | `App/`, `App/project.yml` |
| Oddzielne Bundle ID, Keychain i zadanie tła | WYKONANE | roboczo `com.kuba.motohub.appstorecandidate`, od 2026-09-16 `pl.mintstudio.findhubandroid` |
| Generowanie XcodeGen | PASS | Utworzony `App/FindHub Android.xcodeproj`, schemat `FindHub Android` |
| Release, iOS device, bez podpisu | PASS | `evidence/build-release-summary.txt`; Xcode 26.6, SDK iOS 26.5 |
| Regresje offline | PASS — 45 kontroli | `evidence/regressions.txt` |
| Historia i reguły ochrony offline | PASS — 44 kontrole | `evidence/journal.txt` |
| Porównanie oryginału | WYKRYTO 3 RÓWNOLEGŁE ZMIANY, nie cofano | `evidence/original-integrity.txt`, bazowy `source-snapshot.json` |
| Spójność linków dokumentacji | Wynik zapisany w evidence | `evidence/document-check.txt` |

Kompilacja zgłosiła ostrzeżenie „Metadata extraction skipped. No AppIntents.framework dependency found.” Aplikacja nie deklaruje tutaj funkcji App Intents. Nie stwierdzono błędów kompilacji. Ta kontrola nie obejmowała podpisania dystrybucyjnego ani walidacji App Store Connect.

## Niewykonane i nadal otwarte (stan 2026-09-16, kanał AltStore PAL)

- Strona projektu, polityka prywatności, kontakt — DO PRZYGOTOWANIA.
- UX-01 (stany błędów i uprawnień), BLE-01, SEC-02 — DO WDROŻENIA.
- Konto Apple, Alternative Terms Addendum, rejestracja AltStore PAL — NIEWYKONANE (użytkownik).
- Testy fizyczne i instalacja tej kopii, w tym usuwania danych konta — NIERUCHOMIONE.
- Archiwum z podpisem dystrybucyjnym, notaryzacja, ADP, źródło AltStore — NIEWYKONANE.

## Rejestr decyzji do uzupełnienia

| ID | Decyzja | Status | Dokument/dowód | Osoba/data |
|---|---|---|---|---|
| D01 | Dopuszczalny zakres Google/API | ZASTĄPIONE przez D13 — brak publicznego API; ryzyko przyjęte | `09-RYZYKA.md` | Użytkownik, 2026-09-16 |
| D02 | Licencja portowanych elementów | ZASTĄPIONE przez D14 | `LICENSE`, `App/Resources/Licenses/` | Użytkownik, 2026-09-16 |
| D03 | Nazwa publiczna: FindHub Android | ZAAKCEPTOWANE | Wyraźna decyzja użytkownika w rozmowie | Użytkownik, 2026-09-16 |
| D12 | Finalny Bundle ID: `pl.mintstudio.findhubandroid` | ZAAKCEPTOWANE | Plan zatwierdzony w rozmowie | Użytkownik, 2026-09-16 |
| D11 | Zachowanie obecnej ikony w wydaniu App Store | ZAAKCEPTOWANE | Wyraźna decyzja użytkownika w rozmowie | Użytkownik, 2026-09-16 |
| D04 | Wydawca, kraje i status DSA | OTWARTE | — | — |
| D05 | Model płatności | OTWARTE | — | — |
| D06 | Dane, odbiorcy, retencja i etykiety | OTWARTE | — | — |
| D07 | Klasyfikacja szyfrowania | OTWARTE | — | — |
| D08 | Wspierane tagi, systemy i funkcje startowe | OTWARTE | — | — |
| D09 | Konto/demo i sprzęt do review | OTWARTE | — | — |
| D10 | Decyzja o wydaniu konkretnego builda | OTWARTE | — | — |
| D13 | Kanał dystrybucji: AltStore PAL w UE z notaryzacją; bez App Store | ZAAKCEPTOWANE | Decyzja w rozmowie po analizie 5.2.2 i notaryzacji | Użytkownik, 2026-09-16 |
| D14 | Licencja aplikacji: GNU GPL v3.0 lub nowsza, publiczny kod | ZAAKCEPTOWANE | Wynika z D13 i portu GoogleFindMyTools | Użytkownik, 2026-09-16 |
| D15 | Wydawca: mintstudio (mintstudio Jakub Koncewicz), kontakt@mintstudio.pl | ZAAKCEPTOWANE | Decyzja w rozmowie | Użytkownik, 2026-09-16 |
| D16 | Publiczne repozytorium `darthkubox/FindHub-Android`, commity z kontakt@mintstudio.pl | ZAAKCEPTOWANE | Decyzja w rozmowie | Użytkownik, 2026-09-16 |

## Zasady dowodów

Wersja, numer builda i data są obowiązkowe. PASS bez wskazania sprawdzanego zakresu nie wystarcza. Dane kont, hasła, lokalizacje i poufne umowy trzymaj poza repozytorium; wpisuj jedynie identyfikator i opis dowodu. Po każdej istotnej zmianie integracji zaktualizuj dokumentację i powtórz adekwatne testy.

Hashy w `source-snapshot.json` używa się tylko do wykrywania zmian oryginału względem chwili kopiowania; nie cofają żadnych zmian i nie blokują użytkownikowi późniejszej niezależnej pracy nad starym projektem.

## Rozbieżności oryginału zauważone podczas pracy

Kontrola SHA-256 wykryła zmiany w `MotoHub/Sources/M3BottomDrawer.swift`, `MotoHub/Sources/DeviceDetailView.swift` i głównym `CLAUDE.md` od momentu zapisania bazowego snapshotu. Ta praca nie wykonywała edycji tych plików. Nie ustalano autora równoległych zmian ani nie nadpisywano ich.

Kopia obu plików Swift odpowiada dokładnie początkowemu snapshotowi. Porównanie wszystkich skopiowanych plików z tym snapshotem potwierdziło wyłącznie planowane różnice tożsamości i dokumentacji — szczegóły w `evidence/copy-changes.txt`. Historia późniejszych poprawek oryginału nie jest automatycznie częścią tej kopii.

## Ujednolicenie nazwy — 2026-09-16

Na polecenie użytkownika nazwa produktu to **FindHub Android**. Zmieniono nazwę folderu wydania, projektu/schematu Xcode, modułu, tekstów UI i opisów uprawnień; uzupełniono dokumentację i szablony. Obecna ikona oraz Bundle ID i przestrzeń Keychain pozostały bez zmian. Historyczne dowody poprzedniej kompilacji zachowano pod pierwotnymi nazwami; nowy wynik zapisujemy osobno w `evidence/build-name-update.txt`.

Weryfikacja zmiany nazwy: zwykły build Release — PASS; build-for-testing z jednorazowym `ENABLE_TESTABILITY=YES` — PASS. Sprawdzono nazwę w zbudowanym Info.plist i opisy uprawnień oraz identyczność ikony. Testów XCTest nie uruchamiano i nie instalowano nowej kopii na telefonie.

## Przygotowanie pod AltStore PAL — 2026-09-16

Zmiany w kopii:

- Przeniesione z MotoHub: `M3BottomDrawer.swift` (peek 124 pt), `DeviceDetailView.swift` (bez linii `model.status`). Testy w `Tests/` różnią się od oryginału tylko nazwą modułu.
- PRIV-03: `TrackerJournal.deleteActiveAccountData()` i `deviceIDsInOtherAccounts()`, `NameStore/IconStore.remove(_:)`, `DeviceProtection.removeNotifications(for:)`, `AppModel.deleteActiveAccountLocalData()`. W Ustawieniach dodano akcję z potwierdzeniem. Wpisy nazw, ikon i zdjęć urządzeń zapisanych także w pliku innego konta nie są usuwane.
- SEC-01: nazwa urządzenia w logu `Nova.swift` jest `.private`.
- PRIV-01: `App/Resources/PrivacyInfo.xcprivacy`.
- OSS-01/LIC-02: `LICENSE` (GPLv3), `App/Resources/Licenses/{ACKNOWLEDGEMENTS,GPL-3.0}.txt`, `Legal/SwiftProtobuf-LICENSE.txt`, `LicensesView.swift`, klucz `FHASourceCodeURL` z ustawienia `SOURCE_CODE_URL`.
- Podpis: `DEVELOPMENT_TEAM` przeniesiony do nieśledzonego `App/Config/Local.xcconfig` (wzór: `Local.xcconfig.example`).
- Dokumentacja: nowe `06-ALTSTORE-PAL.md`, `09-RYZYKA.md`, `templates/altstore-source.json`; zaktualizowane README, AGENTS, 01, 03; materiały App Store w `archiwum/`.

Weryfikacja: [evidence/altstore-prep-2026-09-16.txt](evidence/altstore-prep-2026-09-16.txt) — 45 regresji, 50 kontroli historii (w tym 6 nowych dla usuwania danych konta), build Release bez podpisu i 4 testy XCTest przeszły. Nowych ekranów nie sprawdzano ręcznie z zalogowanym kontem ani na telefonie.

## Repozytorium, licencje i wydawca — 2026-09-16

- Bundle ID `pl.mintstudio.findhubandroid`: `project.yml`, usługa Keychain, zadanie w tle, identyfikator przywracania Bluetooth, subsystem logów. Instalacja nie przejmuje danych wcześniejszego roboczego ID.
- Ustawienia → O aplikacji: wydawca, kontakt, link do kodu (`FHAPublisher`, `FHAPublisherContact`, `FHASourceCodeURL`).
- Nagłówki SPDX `GPL-3.0-or-later` we wszystkich plikach Swift aplikacji, testów i skryptu ikony; w plikach portowanych źródło, autor i licencja.
- `ACKNOWLEDGEMENTS.txt`: wydawca, znaki towarowe, specyfikacje i materiały referencyjne, cytowanie GoogleFindMyTools. Nowe `NOTICE`, angielski `README.md` z tabelą autorów i licencji, polski przegląd w `docs/00-PRZEGLAD.md`, logo mintstudio w `docs/assets` (poza GPL).
- Szablony źródła AltStore, metadanych i polityki prywatności uzupełnione o wydawcę.

Weryfikacja: [evidence/github-release-prep-2026-09-16.txt](evidence/github-release-prep-2026-09-16.txt).

## Polityka prywatności i warunki korzystania — 2026-09-17

- `App/Resources/Legal/polityka-prywatnosci.md` i `warunki-korzystania.md` (wersja 1). Treść polityki oparta na przeglądzie kodu: endpointy Google (`android.clients.google.com`, `android.googleapis.com/nova`, `spot-pa.googleapis.com`, FCM/Firebase Installations, `mtalk.google.com`, `accounts.google.com`, `openidconnect.googleapis.com`), MapKit i `CLGeocoder` Apple, zewnętrzne aplikacje map na polecenie użytkownika, `PhotosPicker`, Keychain `AfterFirstUnlockThisDeviceOnly`, historia wyłączona z kopii zapasowej.
- `LegalDocumentView.swift`: wyświetlanie dokumentów, `LegalConsent` z wersjonowaniem. Ekran logowania: informacja o nieoficjalnym kliencie, linki i akceptacja; logowanie nieaktywne bez akceptacji. Ustawienia: sekcja „Informacje prawne”.
- Publiczne URL: https://github.com/darthkubox/FindHub-Android/blob/main/App/Resources/Legal/polityka-prywatnosci.md oraz https://github.com/darthkubox/FindHub-Android/blob/main/App/Resources/Legal/warunki-korzystania.md.
- Testy: `Tests/LegalTests.swift` (dokumenty i licencje w paczce, wydawca, renderowanie, wersjonowanie zgody). Wyniki: [evidence/legal-2026-09-17.txt](evidence/legal-2026-09-17.txt) — XCTest 6/6, regresje 45, historia 50, build Release PASS. Zrzut ekranu logowania z symulatora obejrzany. Ekranów dokumentów nie klikano ręcznie; na telefonie nie testowano.
- Po podbiciu `LegalDocument.currentVersion` zalogowany użytkownik widzi pełnoekranową prośbę o ponowną akceptację (nie da się jej zamknąć bez akceptacji).

## Wielojęzyczność — 2026-09-17

Polecenie użytkownika: dokumenty i licencje po polsku i angielsku, aplikacja w wielu językach (wybór: PL, EN, DE, FR, ES, IT; dokumenty prawne PL+EN, pozostałe języki pokazują EN).

- `App/Resources/Localizable.xcstrings` (329 tekstów, formy liczby mnogiej) i `InfoPlist.xcstrings` (opisy uprawnień). Klucze po polsku (`developmentLanguage: pl`), język zapasowy angielski (`DEVELOPMENT_LANGUAGE: en` → `CFBundleDevelopmentRegion = en`).
- Kod: komunikaty modelu, powiadomień, błędów i BLE przez `String(localized:)`; parametry widoków pomocniczych jako `LocalizedStringKey`; ręczna polska liczba mnoga zastąpiona katalogiem; daty w języku aplikacji zamiast stałego `pl_PL`; zgadywanie ikony miejsca rozpoznaje słowa we wszystkich językach.
- Dokumenty: `privacy-policy.md`, `terms-of-use.md`, `ACKNOWLEDGEMENTS-en.txt` obok wersji polskich; aplikacja wybiera PL dla polskiego interfejsu, EN dla pozostałych. `README.md` (EN) + `README.pl.md`, `NOTICE` + `NOTICE.pl`, `Legal/README.md` (EN) + `Legal/README.pl.md`. Szablon źródła AltStore i metadanych — opis EN z polskim.
- Testy: `LocalizationTests` (6 lokalizacji w paczce, tłumaczenia kluczowych tekstów, polska liczba mnoga 1/3/5, zapasowy EN), rozszerzone `LegalTests` (obie wersje dokumentów, te same sekcje i wersja). Wyniki: [evidence/localization-2026-09-17.txt](evidence/localization-2026-09-17.txt) — XCTest 7/7, regresje 45, historia 50, build Release PASS. Zrzuty symulatora: interfejs po niemiecku oraz angielski przy języku czeskim.
- Ograniczenia: tłumaczenia DE/FR/ES/IT przygotowane bez weryfikacji native speakera; dokumenty prawne EN to tłumaczenie wersji polskiej (rozstrzyga polska). Wewnętrzna dokumentacja `docs/` pozostaje po polsku.

## Źródła projektów i menu konta — 2026-09-17

- Projekty, na których opiera się aplikacja, z dokładną wersją i linkiem do oryginalnego repozytorium: w aplikacji (`UpstreamProject` w `LicensesView.swift`, klikalna lista), w `ACKNOWLEDGEMENTS-{pl,en}.txt`, `README.md`/`README.pl.md` (kolumna wersji), `NOTICE`/`NOTICE.pl`, `Legal/README*.md`. Sprawdzone: wszystkie repozytoria istnieją (GitHub API), linki Chromium i specyfikacji zwracają HTTP 200, commit GoogleFindMyTools `d46e952` istnieje upstream, pliki `uECC.c`/`uECC.h` są identyczne (SHA-256) z micro-ecc `master` `541b3a7`. Adres http_ece zaktualizowany na `web-push-libs/encrypted-content-encoding` (przekierowanie upstream).
- Menu konta (stuknięcie w awatar): nowa pozycja „Informacje prawne i licencje” → `LegalInfoView` (polityka, warunki, licencje, wydawca, kontakt, kod źródłowy).
- Poprawka skryptu katalogu tłumaczeń: klucze z liczbą mnogą są eksportowane jako warianty i wcześniej wypadały z katalogu; wykrył to `LocalizationTests`. Katalog: 345 tekstów.
- Testy: nowy `LegalScreensTests` (menu konta, informacje prawne, licencje — zrzuty obejrzane), `LegalTests` sprawdza zgodność listy projektów z plikami licencji w obu językach. XCTest 8/8, regresje 45, historia 50, build Release PASS.

## Ekran logowania i odblokowanie kluczy — 2026-09-17 (zgłoszenie z testu na telefonie)

- Ekran startowy: ikona aplikacji (`AppLogo`, kształt ikony iOS) zamiast symbolu; podtytuł „Sprawdź swoje androidowe lokalizatory na iOS” we wszystkich 6 językach.
- Odblokowanie kluczy E2EE i logowanie Google: zamiast arkusza okno pełnoekranowe, bez gestu ściągania; WebView bez efektu sprężynowania. Otwieranie logowania z menu konta i ustawień czeka na zamknięcie poprzedniego arkusza.
- Weryfikacja: zrzut ekranu logowania z testu (`LegalScreensTests`), XCTest 8/8, regresje 45, historia 50, build Release PASS. Rysowania wzoru na telefonie po zmianie nie sprawdzano — do potwierdzenia przez użytkownika.

## Dół ekranów pod paskiem nawigacji — 2026-09-17 (zgłoszenie z telefonu)

- Objaw: w szczegółach urządzenia ostatnia karta („Diagnostyka odczytu”) była ucięta przez dolny pasek nawigacji. Test `ScrollInsetTests` odtworzył to: po przewinięciu do końca treść kończyła się 80 pt pod paskiem, bo ekrany wypchnięte w `NavigationStack` nie dziedziczą rezerwy powłoki.
- Poprawka: `EnvironmentValues.tabBarReserve` ustawiane w `MainTabsView` i modyfikator `.clearsTabBar()` na ekranach szczegółów urządzenia, historii, pilnowania, listy miejsc i szczegółów miejsca.
- Weryfikacja: `ScrollInsetTests` PASS (treść kończy się nad paskiem, bez nadmiernej przerwy; zrzut obejrzany), XCTest 9/9, regresje 45, historia 50, build Release PASS.

## Powiadomienia i usunięcie dzwonienia przez sieć — 2026-09-17 (zgłoszenie z telefonu)

- Przyczyna braku powiadomień: zgoda iOS była wymagana tylko w „Pilnowanie urządzenia”. Przypisanie urządzenia do miejsca w zakładce Miejsca (`PlaceAssignment.set`) włączało alerty bez prośby o zgodę, więc iOS ich nie wyświetlał.
- Teraz: prośba o zgodę przy zapisaniu miejsca i przy przypisaniu urządzenia; `NotificationPermissionCard` (włącz / otwórz ustawienia iOS) w Ustawieniach, liście miejsc, szczegółach miejsca i pilnowaniu urządzenia.
- Ustawienia → Powiadomienia: przełączniki „Opuszczenie miejsca”, „Utrata kontaktu Bluetooth”, „Nazwy urządzeń i miejsc w treści” (tekst bez nazw na ekranie blokady), „Wyślij powiadomienie testowe” (za 5 s).
- Usunięto dzwonienie przez sieć (`AppModel.ring`, `Nova.playSound`, przycisk w szczegółach) — nie zostało potwierdzone na urządzeniu. Dzwonienie przez Bluetooth zostaje. Polityka prywatności PL/EN 1.1: bez zapytań o dzwonienie, opis przełącznika nazw w powiadomieniach (zawężenie przetwarzania, bez ponownej akceptacji).
- Weryfikacja: XCTest 10/10 (nowy `NotificationSettingsTests`, zrzut Ustawień obejrzany), regresje 45, historia 50, build Release PASS, 355 tekstów w 6 językach. Dostarczenia alertu miejsca w tle na telefonie nie potwierdzono — do sprawdzenia przyciskiem testowym i w terenie.
