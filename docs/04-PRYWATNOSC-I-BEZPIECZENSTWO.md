# Dane, prywatność i bezpieczeństwo

Dokument roboczy oparty o kod na 2026-09-16. Nie zastępuje publicznej polityki ani ostatecznych odpowiedzi App Privacy. Autoryzację Google planujemy zmienić, więc finalny audyt należy powtórzyć po zmianach.

## Wstępna mapa danych

| Dane | Obecne użycie i miejsce | Przepływ poza telefon | Co ustalić / zmienić |
|---|---|---|---|
| E-mail i awatar Google | Wybór konta; cache awatara i informacje konta | Uwierzytelnianie i pobranie profilu od Google | Minimalne scopes, retencja i kasowanie |
| Master/AAS, tokeny usługi, poświadczenia FCM | Keychain; dostęp po pierwszym odblokowaniu, bez migracji kopią | Używane w uwierzytelnionych żądaniach Google | Zastąpić zatwierdzonym przepływem; zbadać odwołanie dostępu |
| Klucze E2EE | Keychain, odszyfrowanie na urządzeniu | Uzyskiwane z procesu Google | Uprawnienie i zgoda; brak logowania kluczy |
| Lokalizacja iPhone’a | Pozycja na mapie i dystanse | Sprawdzić przepływy MapKit; trasa zewnętrzna po akcji użytkownika | Uwzględnić tylko rzeczywiste wysyłane dane |
| Raporty tagów, identyfikatory urządzeń | Pobierane z Google, odszyfrowane lokalnie | Zapytania i identyfikatory trafiają do Google | Zidentyfikować wszystkie endpointy i pola |
| Historia, trasy | `Application Support/TrackerJournal`; historia starsza niż 7 dni przycinana przy obsłudze danych | Brak własnego backendu; katalog wyłączony z backupu | Nie obiecywać kasowania dokładnie po 7 dniach na nieuruchamianej aplikacji |
| Notatki i miejsca | Ten sam dokument per konto | Zasadniczo lokalne; zweryfikować wszystkie ścieżki | Wylogowanie zachowuje dane; dodać ich pełne usuwanie |
| Nazwy, ikony, zdjęcia użytkownika | Lokalne stores, UserDefaults i pliki | Sprawdzić backup/cache oraz źródła zdjęć | Spójne kasowanie per konto, izolacja kont |
| Bluetooth | Odkrywanie, identyfikacja i akcje pobliskich tagów | Radio BLE do akcesoriów | Minimalna retencja; nie traktować RSSI jako dowodu własności |
| Powiadomienia | Lokalne alarmy oddalenia/wyjścia | Widoczne na ekranie blokady | Ograniczyć ujawnianie nazw i miejsc; wybór treści |
| Diagnostyka i logi | OSLog i diagnostyka UI | Potencjalnie udostępniane przez użytkownika lub kanał dystrybucji | Redakcja logów, brak sekretów i prywatnych nazw w `.public` |

Na potrzeby etykiety Apple dane przetwarzane wyłącznie na urządzeniu nie są automatycznie „zbierane”. Konieczna jest jednak analiza przesyłania do Google, Apple i ewentualnych SDK; nie wystarczy brak własnego serwera. [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

## Plan inwentaryzacji końcowej

1. Zmapować każde wywołanie `URLSession`, socket MCS, WebView, MapKit i otwarcie zewnętrznego URL.
2. Dla każdego określić dane, cel, odbiorcę, moment zgody, retencję i niezbędność.
3. Sprawdzić wszystkie magazyny: Keychain, UserDefaults, pliki, URLCache, WebKit, dzienniki, backup.
4. Porównać z zależnościami i manifestami ich dokładnych wersji.
5. Zweryfikować zachowanie na koncie testowym; zapis ruchu/logów musi być oczyszczony z sekretów.
6. Na tej podstawie uzupełnić politykę, manifest i etykiety App Privacy jako trzy odrębne dokumenty.
7. Ponowić audyt po dodaniu analityki, SDK, płatności, crash reportingu albo backendu.

## Kasowanie i odłączanie konta

**Stan 2026-09-16:** w Ustawieniach działa „Usuń dane tego konta z telefonu” (`AppModel.deleteActiveAccountLocalData`). Usuwa plik historii/notatek/miejsc konta, sekrety w Keychain, awatar, oczekujące i dostarczone powiadomienia konta oraz nazwy, ikony i zdjęcia urządzeń, które nie występują w pliku innego konta. Sprawdzone testami offline; niesprawdzone na telefonie. Odwołanie dostępu po stronie Google (PRIV-04) pozostaje otwarte.

Docelowy interfejs powinien rozróżniać:

- **Wyloguj** — usuwa poświadczenia lokalne i zatrzymuje aktywność konta; jasno informuje, czy zachowuje notatki/historię.
- **Usuń dane tego konta z telefonu** — z potwierdzeniem usuwa powiązane pliki, nazwy, ikony, zdjęcia, klucze i tokeny, pending notifications, monitorowanie BLE i miejsca.
- **Cofnij dostęp Google** — faktyczna, zatwierdzona operacja odwołania lub instrukcja właściwa dla przyjętej integracji. Lokalne usunięcie tokena nie jest odwołaniem go na serwerze.

Test: dane konta B pozostają nietknięte podczas kasowania A; po ponownym uruchomieniu i ponownym zalogowaniu usunięte dane lokalne nie wracają. Wykonać również test przerwania procesu w połowie kasowania i błędu Keychain/dysku.

Nie należy oferować „usunięcia konta Google” ani sugerować, że aplikacja usuwa samo konto u Google. Jeśli w przyszłości powstanie własna rejestracja konta produktu, ponownie sprawdzić wymagania Apple dotyczące inicjowania usunięcia konta. [Usuwanie kont według Apple](https://developer.apple.com/support/offering-account-deletion-in-your-app/).

## Uprawnienia

- Lokalizacja: prośba przy funkcji wymagającej pozycji; obsługa odmowy, ograniczonej dokładności i późniejszej zmiany w Ustawieniach.
- Bluetooth: opis celu zgodny z lokalnym namierzaniem i pilnowaniem; brak automatycznego twierdzenia, że wykryty tag należy do użytkownika.
- Powiadomienia: prośba w kontekście włączenia alertów; brak zgody nie może blokować mapy i listy tagów.
- Zdjęcia: preferować systemowy picker; nie dodawać szerokiego uprawnienia do biblioteki bez potrzeby.
- Tryby `bluetooth-central` i `fetch`: zachować tylko przy realnym, przetestowanym użyciu. Odświeżanie systemowe nie ma gwarantowanego harmonogramu.

Opisy uprawnień w `App/project.yml` należy ostatecznie dopasować do nazwy i zachowania produkcyjnego. [Apple: ochrona prywatności](https://developer.apple.com/documentation/uikit/protecting-the-user-s-privacy).

## Bezpieczeństwo przed wydaniem

- Przejrzeć `Nova.swift` i inne logi `.public`: nazwy urządzeń i lokalizacje nie powinny być ujawniane domyślnie.
- Zweryfikować allowlisty hostów, origin skryptów i callbacks autoryzacji. Po przebudowie logowania usunąć niewykorzystywane ścieżki odczytu cookies/bridge.
- Przetestować wylogowanie i zmianę konta podczas trwającego zapytania: spóźniona odpowiedź nie może wprowadzić danych poprzedniego konta.
- Audytować retencję surowych raportów, kluczy w pamięci i błędy odszyfrowania; nie logować payloadów.
- Przejrzeć bibliotekę C, wektory kryptograficzne i obsługę niepoprawnych danych.
- Przygotować kontakt zgłoszeń bezpieczeństwa oraz procedurę reakcji na cofnięcie dostępu Google.
- Nie składać obietnic „alarm antykradzieżowy zawsze zadziała” lub śledzenia co określoną liczbę minut w tle.

## Szyfrowanie i export compliance

Występują CryptoKit/CommonCrypto oraz implementacje AES-EAX i micro-ecc. Sporządzić listę algorytmów, bibliotek, zastosowań i krajów dystrybucji. Następnie przejść ankietę szyfrowania App Store Connect; ustalić wymagane dokumenty lub podstawę wyjątku i dopiero wpisać właściwe klucze Info.plist. Ewentualne obowiązki raportowe i wymagania krajowe ocenić dla konkretnego produktu. [Przewodnik Apple](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance).

## Publiczne materiały

Szablon [polityki prywatności](templates/POLITYKA-PRYWATNOSCI.md) zawiera pola do uzupełnienia i opis bieżących ograniczeń. Przed publikacją ustalić operatora, podstawy przetwarzania, kontakt, odbiorców, okresy retencji i właściwe prawa użytkowników. Nie publikować szablonu z placeholderami ani stwierdzeń sprzecznych z wdrożonym kodem.
