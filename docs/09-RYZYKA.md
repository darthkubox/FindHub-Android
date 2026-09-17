# Ryzyka wydania poza App Store

Stan: 2026-09-16. Ryzyka zaakceptowane przez użytkownika przy wyborze AltStore PAL. Dokument nie jest opinią prawną.

| ID | Ryzyko | Skutek | Jak ograniczamy |
|---|---|---|---|
| R1 | Google nie udostępnia publicznego API Find Hub. Aplikacja korzysta z endpointów i tożsamości klienta aplikacji Android, logowania w WebView i strony odblokowania kluczy dla Androida. Narusza to [zasady OAuth](https://developers.google.com/identity/protocols/oauth2/policies) i warunki Google. | Google może zmienić protokół lub zablokować dostęp; aplikacja przestaje działać do czasu poprawki albo na stałe. | Opis sklepu i ekran licencji mówią o nieoficjalnym kliencie. Nie obiecujemy dostępności usługi. |
| R2 | Google może oznaczyć lub zablokować konto logowane nieoficjalnym klientem. | Utrata dostępu do konta lub konieczność weryfikacji. | Ostrzeżenie w opisie. Przed wydaniem zmierzyć częstotliwość zapytań w tle i na pierwszym planie (T27). |
| R3 | Nazwa „Tagpin” zawiera znaki towarowe Google (Find Hub, Android). | Wezwanie od Google do AltStore lub do wydawcy, usunięcie aplikacji ze źródła. [Wytyczne AltStore](https://faq.altstore.io/developers/app-guidelines) wymagają praw do treści. | Nazwa zostaje (decyzja użytkownika). Informacja o znakach i braku powiązania w aplikacji i opisie. Przygotować awaryjną zmianę nazwy (`project.yml`, UI). |
| R4 | GPLv3 portu GoogleFindMyTools. | Obowiązek udostępnienia pełnego kodu każdej rozprowadzanej wersji. | Publiczne repozytorium, `LICENSE`, adres kodu w aplikacji (`SOURCE_CODE_URL`), tag Git dla każdej wersji. |
| R5 | Notaryzacja nadal obowiązuje (bezpieczeństwo, prywatność, 2.3.1, rzetelny opis). | Odmowa notaryzacji. | Brak ukrytych funkcji, manifest prywatności, usuwanie danych, zgodne opisy uprawnień. |
| R6 | Dystrybucja tylko w UE (oraz Japonii i Brazylii przez AltStore PAL). | Brak użytkowników spoza tych krajów. | Informacja w opisie. |
| R7 | Zmiany warunków Apple dla dystrybucji alternatywnej i opłat. | Koszt lub dodatkowe obowiązki. | Sprawdzić aktualne warunki przed każdym wydaniem (`06-ALTSTORE-PAL.md`). |
| R8 | Aplikacja lokalizująca może być oceniona jako narzędzie do śledzenia ludzi. | Odmowa notaryzacji lub skargi. | Dostęp tylko do urządzeń własnego konta Google, brak ukrytego trybu, DULT pozwala wykryć tag. Opis jasno podaje cel. |
