# Macierz testów i kryteria przyjęcia

Testy opisane tutaj są planem. Ich wykonanie zapisuje się w `07-STAN-I-DOWODY.md`. Testy starej aplikacji nie są automatycznie wynikiem dla nowego Bundle ID ani przyszłego flow logowania.

## Warunki testu

- Rejestrować: wersję/build, hash źródeł, model telefonu, iOS, model/firmware taga, typ konta, stan uprawnień i sieci.
- Korzystać z odrębnego konta i tagów testowych. Nie dostarczać Apple prywatnego konta właściciela ani historii jego miejsc.
- Co najmniej: najstarszy deklarowany iOS 17 (lub zmienione minimum), aktualny iOS, najmniejszy wspierany ekran i współczesny iPhone.
- Funkcje Bluetooth, tła i dźwięku sprawdzać fizycznie. Symulator potwierdza UI i część logiki, nie zachowanie taga.
- Nie deklarować kompatybilności z modelem taga, którego nie przetestowano.

## Automatyczne kontrole

Z katalogu głównego kopii:

```bash
bash Scripts/check_local.sh
bash Scripts/check_local.sh --build
```

Testy UI/XCTest wymagają działającego symulatora. Najpierw odczytać istniejące urządzenia, następnie zastąpić `SIMULATOR_UDID` rzeczywistą wartością:

```bash
xcrun simctl list devices available
xcodebuild -project "App/Tagpin.xcodeproj" -scheme "Tagpin"   -destination 'platform=iOS Simulator,id=SIMULATOR_UDID'   -derivedDataPath /tmp/tagpin-ui-tests   test CODE_SIGNING_ALLOWED=NO
```

Zakres obecnych testów offline: korelacja odpowiedzi i kont, anulowanie, kryptografia, kadrowanie mapy, lokalna historia, reguły miejsc i pilnowania. Testy XCTest obejmują wygląd i interakcje oparte o syntetyczne fixtures. `AppModel()` przy inicjalizacji aktywuje konto sesji; fixture należy aktywować po utworzeniu modelu, by nie zapisać danych w złym kontekście.

## Scenariusze obowiązkowe przed pierwszym wydaniem

| ID | Scenariusz | Oczekiwany wynik |
|---|---|---|
| T01 | Czysta instalacja kopii obok starej aplikacji | Osobna instalacja i sandbox, z tą samą zaakceptowaną grafiką ikony; brak odczytu/usuwania kont starej wersji |
| T02 | Pierwsze dozwolone logowanie + MFA/passkey | Właściwa tożsamość klienta, zakończenie bez ręcznego kopiowania tokenów |
| T03 | Anulowanie, odmowa consent, błąd sieci, cofnięcie dostępu | Jasny błąd i możliwość ponowienia; brak zawieszenia i częściowych sekretów |
| T04 | Odblokowanie kluczy E2EE + anulowanie/błędny warunek | Brak dostępu bez autoryzacji, brak kluczy w logach |
| T05 | Konto bez tagów i konto z kilkoma modelami | Poprawny pusty stan; obsłużone/nieobsłużone modele rozróżnione |
| T06 | Lokalizacja własna i sieciowa | Właściwy tag, czas i dokładność; brak mylenia starej pozycji z bieżącą |
| T07 | Odświeżenie podczas poprzedniego zapytania | Anulowanie/spóźnione raporty bez nadpisania nowszego stanu |
| T08 | Zmiana konta podczas pobierania | Dane i akcje trafiają wyłącznie do właściwego konta |
| T09 | Sieć offline, utrata Wi-Fi, zmiana Wi-Fi/komórkowa | Kontrolowany timeout, czytelny stan, odzyskanie bez restartu aplikacji |
| T10 | Lokalizacja wyłączona/przybliżona/odmówiona | Nadal dostępne funkcje niewymagające pozycji telefonu |
| T11 | Bluetooth wyłączony/odmówiony | Poprawne wyjaśnienie, brak fałszywego alertu oddalenia |
| T12 | Dzwonienie lokalne, dwa tagi obok siebie | UI uczciwie opisuje wybór najbliższego; fizycznie potwierdzony dźwięk |
| T13 | Dzwonienie sieciowe | Właściwy tag; odróżnienie przyjęcia żądania od faktycznego dźwięku |
| T14 | Pilnowanie: prawdziwa utrata kontaktu i szybki powrót | Opóźnienia respektowane, anulowanie po powrocie, brak lawiny alertów |
| T15 | Telefon zablokowany, tło, restart, force-quit | Zachowanie i ograniczenia zapisane, brak obietnic niepotwierdzonych testem |
| T16 | Powiadomienia odmówione / włączone później | Czytelny stan ochrony i możliwość naprawy |
| T17 | Wyjście z miejsca, granica dokładności i stare raporty | Alert tylko przy spełnieniu rzeczywistych kryteriów świeżości i pewności |
| T18 | Historia 7 dni, duplikaty, brak raportów, zmiana zegara | Brak fabrykowanych punktów; luki w trasie widoczne |
| T19 | Zapis notatek/miejsc, restart, uszkodzony plik | Dane poprawne; brak cichego nadpisania nieczytelnego magazynu |
| T20 | Wylogowanie i pełne usunięcie danych | Zachowanie zgodne z wyborem; wyłączone akcje i powiadomienia danego konta |
| T21 | Usunięcie konta A przy istniejącym B | B pozostaje nienaruszone; A nie wraca po restarcie |
| T22 | Aktualizacja z poprzedniej wersji tej kopii | Migracja lokalnych danych bez utraty i pomylenia kont |
| T23 | VoiceOver, duży tekst, jasny/ciemny motyw | Kluczowe akcje czytelne i osiągalne; poprawne etykiety ikon |
| T24 | Zewnętrzne mapy zainstalowane/niezainstalowane | Właściwe współrzędne i fallback; akcja wynika z polecenia użytkownika |
| T25 | Linki polityki i supportu | Działają publicznie bez logowania, na telefonie i przy recenzji |
| T26 | Tryb demo / konto recenzenckie | Dostępna pełna zadeklarowana funkcjonalność; demo oznaczone i bez prywatnych danych |
| T27 | Dłuższa sesja, dzień pracy w tle, wiele tagów | Udokumentowane zużycie energii i sieci; brak niekończących się pętli |
| T28 | Release i archiwum dystrybucyjne | Manifesty, ikona, podpis, wersja i URL-e zgodne z zatwierdzonym zakresem |

## Kryteria jakości

- 0 otwartych defektów ujawniających dane, mylących konta, wybierających błędne urządzenie lub powodujących crash podstawowej ścieżki.
- Każda funkcja reklamowana w sklepie ma przeprowadzony test fizyczny, jeśli zależy od telefonu/taga.
- UI rozróżnia ostatnią znaną pozycję od nowego raportu, a wysłane żądanie od wykonanej akcji.
- Brak nieudokumentowanych blokad logowania, timeoutów bez końca i placeholderów w metadanych.
- Ostateczny numer builda odpowiada testowanemu archiwum; każda późniejsza zmiana wymaga adekwatnego retestu.

## Szablon wyniku

```text
Test ID:
Wersja/build/hash:
Telefon/iOS:
Tag/firmware:
Konto testowe (alias, bez hasła):
Warunki:
Kroki:
Wynik oczekiwany:
Wynik rzeczywisty:
PASS / FAIL / NOT RUN:
Dowód (oczyszczony screenshot/log):
Defekt i właściciel:
Data/tester:
```

## Granice testów wykonanych przy utworzeniu folderu

Przeprowadzono tylko kontrole opisane jako wykonane w rejestrze dowodów. Nowej kopii nie zainstalowano na telefonie; wcześniejsza instalacja oryginału przez Wi-Fi nie zalicza T01 ani pozostałych testów fizycznych kopii.
