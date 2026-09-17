# Backlog przygotowania aplikacji

Wszystkie ścieżki odnoszą się do `App/` w tym nowym projekcie. Priorytet P0 oznacza blocker dystrybucji, P1 warunek naszego pierwszego wydania, P2 zadanie zależne od zakresu produktu. Kryteria są planem inżynierskim pod notaryzację i AltStore PAL.

## Zadania i definicje ukończenia

| ID | Priorytet | Zadanie / obszar | Definicja ukończenia | Stan |
|---|---|---|---|---|
| OSS-01 | P0 | Publikacja kodu na GPLv3 | `LICENSE`, licencje komponentów w aplikacji, publiczne repozytorium i `SOURCE_CODE_URL`, tag każdej wersji | CZĘŚCIOWO — pliki i ekran gotowe (2026-09-16); brak repozytorium |
| LIC-02 | P0 | Notices i licencje w aplikacji | `Resources/Licenses/ACKNOWLEDGEMENTS-{pl,en}.txt`, `GPL-3.0.txt`, ekran „Licencje i kod źródłowy” | ZROBIONE 2026-09-16 |
| PRIV-01 | P1 | Privacy manifest | `Resources/PrivacyInfo.xcprivacy` w bundle, prawdziwe powody | ZROBIONE 2026-09-16 (UserDefaults CA92.1) |
| PRIV-02 | P1 | Polityka prywatności i warunki korzystania | Dokumenty w aplikacji (Ustawienia → Informacje prawne), akceptacja przed logowaniem, publiczne URL w repozytorium | ZROBIONE 2026-09-17 |
| PRIV-03 | P1 | Pełne usunięcie lokalnych danych konta | Historia, miejsca, notatki, nazwy, ikony, zdjęcia, alerty, Keychain; konto B nienaruszone | ZROBIONE 2026-09-16; brak testu na urządzeniu |
| PRIV-04 | P2 | Informacja o cofnięciu dostępu | Instrukcja: myaccount.google.com → Bezpieczeństwo → urządzenia/aplikacje; bez twierdzenia, że aplikacja odwołuje tokeny | OTWARTE |
| SEC-01 | P1 | Logi i sekrety | Brak nazw urządzeń, współrzędnych i tokenów w logach `.public` | ZROBIONE 2026-09-16 (Nova) |
| SEC-02 | P1 | Obsługa błędów zapisu Keychain | Brak fałszywego sukcesu po błędzie; cofnięcie częściowego stanu | OTWARTE |
| UX-01 | P1 | Stany uprawnień i błędów | Lokalizacja odmówiona/przybliżona, BLE wyłączone, offline, brak tagów, błąd konta/Google | ZROBIONE 2026-09-17 |
| BLE-01 | P1 | Uczciwe dzwonienie lokalne | UI mówi „najbliższy zgodny tag”; wysłanie ≠ potwierdzony dźwięk | OTWARTE |
| BG-01 | P1 | Realne możliwości tła | Brak obietnic stałego śledzenia; opis zgodny z testem | OTWARTE |
| DISCL-01 | P1 | Informacja o nieoficjalnym kliencie | Ekran licencji, informacja i akceptacja na ekranie logowania | ZROBIONE 2026-09-17 |
| RELEASE-01 | P1 | Konfiguracja dystrybucyjna | Finalny Bundle ID, podpis, wersja, archiwum | OTWARTE |
| DIST-01 | P1 | Konta i umowy | Apple Developer, Alternative Terms Addendum, token AltStore PAL | OTWARTE — użytkownik |
| DIST-02 | P1 | Notaryzacja | Zatwierdzony build | OTWARTE |
| DIST-03 | P1 | ADP i źródło AltStore | Hosting ADP, `altstore-source.json`, test instalacji | OTWARTE |
| TEST-01 | P1 | Macierz testów | Obowiązkowe przypadki z `05` dla finalnego builda | OTWARTE |
| ACCESS-01 | P2 | Dostępność | VoiceOver/Dynamic Type na kluczowych ścieżkach | OTWARTE |
| CRYPTO-01 | P2 | Przegląd kryptografii | Wektory pozytywne/negatywne, obsługa błędnych danych | OTWARTE |
| LOCAL-01 | P1 | Wersje językowe | UI w PL/EN/DE/FR/ES/IT, dokumenty prawne i licencje PL+EN, test kompletności | ZROBIONE 2026-09-17; tłumaczenia DE/FR/ES/IT do przejrzenia przez native speakerów |

Zadania AUTH-01..03 (zatwierdzony dostęp Google) i REVIEW-01 (App Review) wycofano 2026-09-16 wraz ze zmianą kanału na AltStore PAL. Ryzyko opisuje [09-RYZYKA.md](09-RYZYKA.md).

## Mapa implementacji

- Logowanie i konta: `Sources/LoginWebView.swift`, `GoogleAuth.swift`, `Session.swift`, `AccountUI.swift`, `ContentView.swift`.
- Dostęp do usługi: `Nova.swift`, `SpotClient.swift`, `FcmRegister.swift`, `McsClient.swift`.
- Sekrety i kryptografia: `Keychain.swift`, `VaultUnlock.swift`, `Crypto.swift`, `ForeignTrackerCryptor.swift`, `AesEax.swift`, `HttpEce.swift`, `uECC/`.
- Lokalne dane: `TrackerJournal.swift`, `TrackerJournalData.swift`, `NameStore.swift`, `IconStore.swift`, `DeviceImageStore.swift`, `AppSettings.swift`.
- Uprawnienia i tło: `LocationManager.swift`, `DeviceProtection.swift`, `GuardianBackground.swift`, `project.yml`.
- Branding: `ContentView.swift`, `AccountUI.swift`, `Scripts/make_app_icon.swift`, katalog `AppIcon.appiconset`, display name w `project.yml`.

## Granice zmian

1. Nie stosować ukrytych przełączników ani funkcji włączanych po notaryzacji (Apple 2.3.1 obowiązuje także w notaryzacji).
2. Tryb demo ma być jawnie oznaczony, używać danych syntetycznych i nie uruchamiać prawdziwych akcji zdalnych/BLE.
3. Nie dodawać „Sign in with Apple” wyłącznie dla pozoru; aplikacja jest klientem konta Google, nie ma własnych kont.
4. Nie ustawiać `ITSAppUsesNonExemptEncryption = NO` bez kwalifikacji szyfrowania. W projekcie występuje więcej niż TLS.
5. Nie deklarować „Data Not Collected” wyłącznie z powodu braku własnego serwera.
6. Brak baterii, UWB, parowania nowych tagów lub pewnego sygnału dźwięku nie może być zastępowany fikcyjnymi wartościami w produkcie/screenshotach.

## Privacy manifest — stan

`Resources/PrivacyInfo.xcprivacy` (2026-09-16): `NSPrivacyTracking=false`, `NSPrivacyAccessedAPICategoryUserDefaults` z powodem `CA92.1` (AppSettings, NameStore, IconStore, LocationPresentation). Przeszukanie `Sources` i `uECC` nie wykazało innych API z wymaganym powodem (czas startu systemu, znaczniki czasu plików, miejsce na dysku, klawiatury). `NSPrivacyCollectedDataTypes` jest pusta: aplikacja nie ma własnego serwera ani SDK; dane trafiają wyłącznie do Google w ramach konta użytkownika. Tę kwalifikację trzeba powtórzyć po dodaniu analityki, crash reportingu lub serwera. Manifest SwiftProtobuf opisuje tę bibliotekę. [Required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

## Porządek zmian

Każde zadanie kończy się wpisem: data, zmienione pliki, testy, ograniczenia, powiązana bramka. Nie kopiować poprawek z tej kopii do starego projektu bez nowej dyspozycji użytkownika.
