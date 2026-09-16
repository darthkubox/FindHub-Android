# Polityka prywatności — SZABLON, NIE PUBLIKOWAĆ W TEJ POSTACI

Wypełnić pola, porównać z końcową implementacją i zatwierdzić dla rzeczywistego operatora oraz krajów. To nie jest gotowy dokument prawny. Jeśli określona funkcja nie została wdrożona, nie deklarować jej istnienia.

## 1. Operator i kontakt

Aplikacja: FindHub Android. Operator/administrator w odpowiednim zakresie: mintstudio Jakub Koncewicz, [ADRES], Polska. Kontakt dotyczący prywatności: kontakt@mintstudio.pl. Data wejścia w życie i wersja dokumentu: [DATA/WERSJA]. Zakres działalności i jurysdykcje: [UZUPEŁNIĆ].

## 2. Działanie usługi

Aplikacja służy do [POTWIERDZONY ZAKRES]. Łączy się z [RZECZYWISTE USŁUGI GOOGLE/APPLE I EWENTUALNE INNE]. Obliczenia i odszyfrowywanie lokalizacji [OPISAĆ ZGODNIE Z KODEM]. Wyjaśnić rolę operatora aplikacji oraz niezależnych dostawców usług; nie twierdzić „żadne dane nie opuszczają telefonu”, jeśli odbywają się zapytania Google lub mapowe.

## 3. Dane i cele

Uzupełnić tabelę z audytu, dla każdej kategorii podać niezbędność, cel i odpowiednią podstawę prawną tam, gdzie wymagana:

| Kategoria | Cel | Gdzie przetwarzana/przechowywana | Odbiorcy | Podstawa/zgoda, gdy dotyczy |
|---|---|---|---|---|
| Konto i profil | [ ] | [ ] | [ ] | [ ] |
| Poświadczenia i klucze | [ ] | [ ] | [ ] | [ ] |
| Lokalizacja telefonu i tagów | [ ] | [ ] | [ ] | [ ] |
| Historia, notatki, miejsca, zdjęcia | [ ] | [ ] | [ ] | [ ] |
| Bluetooth i powiadomienia | [ ] | [ ] | [ ] | [ ] |
| Diagnostyka/zgłoszenia wsparcia | [ ] | [ ] | [ ] | [ ] |
| Płatności/analityka, jeżeli wdrożone | [ ] | [ ] | [ ] | [ ] |

Nie wpisywać kategorii zbieranych przez nieistniejącą funkcję. Nie pomijać funkcji dostawcy tylko dlatego, że nie mamy własnego serwera.

## 4. Uprawnienia i wybory użytkownika

Wyjaśnić cele dostępu do lokalizacji, Bluetooth, powiadomień i zdjęć. Opisać, jak odmówić lub cofnąć zgodę systemową i które funkcje przestaną działać. Zgoda systemowa na uprawnienie nie zastępuje wszystkich wymaganych podstaw przetwarzania.

## 5. Przechowywanie i usuwanie

Podać rzeczywiste okresy/warunki dla każdej kategorii. W aktualnej bazie starsza historia jest przycinana podczas obsługi danych, a wylogowanie pozostawia lokalne notatki i historię. Nie obiecywać automatycznego usuwania w dokładnym terminie ani pełnego kasowania przy wylogowaniu, dopóki implementacja tego nie zapewnia.

Po wdrożeniu opisać ścieżki: wylogowanie, pełne usunięcie lokalnych danych konta, cofnięcie autoryzacji Google i kontakt z operatorem. Rozróżnić usunięcie danych aplikacji od usunięcia konta Google. Wyjaśnić backup, reinstalację i możliwe zachowanie Keychain zgodnie z przetestowanym zachowaniem.

## 6. Udostępnianie i transfery

Wymienić faktycznych odbiorców i zasady transferów międzynarodowych, jeśli dotyczy. Dodać zweryfikowane odnośniki do polityk usług. Opisać wybór zewnętrznej aplikacji mapowej i dane przekazywane po tej akcji.

## 7. Bezpieczeństwo

Opisać Keychain, szyfrowane połączenia, lokalne odszyfrowywanie i ochronę plików w zakresie potwierdzonym kodem. Nie składać obietnicy absolutnego bezpieczeństwa ani niedostępności wszystkich danych dla operatora usług zewnętrznych.

## 8. Prawa i kontakt

Wymienić prawa przysługujące użytkownikom w wybranych jurysdykcjach, procedurę żądań, możliwość cofnięcia zgód i właściwy organ skargowy, jeśli wymagane. Wskazać, których lokalnych danych operator bez backendu nie ma możliwości samodzielnie odczytać/usunąć i jak użytkownik usuwa je na telefonie.

## 9. Dzieci, zmiany, pomoc

Określić rzeczywistą grupę odbiorców i wymagania wieku zgodne z usługą Google oraz dystrybucją. Opisać sposób informowania o istotnych zmianach i kontakt pomocy.

## Kontrola przed opublikowaniem

- [ ] Brak nawiasów i placeholderów.
- [ ] Zgodność z finalnym kodem, App Privacy i manifestem.
- [ ] Operator, kontakt, retencja i odbiorcy ustaleni.
- [ ] Link działa publicznie przez HTTPS bez logowania i jest dostępny w aplikacji.
- [ ] Wersja polityki i data zapisane w rejestrze wydania.
