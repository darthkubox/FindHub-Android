# Plan wydania i bramki

Data bazowa: 2026-09-16. Kanał: **AltStore PAL (UE) z notaryzacją Apple**, kod na GPLv3. Wcześniejszy plan pod App Store jest w [archiwum](archiwum/06-APP-STORE-CONNECT.md) i [analizie dostępu Google](archiwum/02-GOOGLE-I-LICENCJE.md).

## Dlaczego nie App Store

Google nie udostępnia API Find Hub niezależnym aplikacjom; istnieje tylko [program dla producentów akcesoriów](https://developers.google.com/nearby/fast-pair/landing-page-find-hub). Punkt 5.2.2 wytycznych Apple wymaga zgody usługi, z której korzysta aplikacja, więc App Review ją odrzuci. Notaryzacja dla dystrybucji alternatywnej w UE obejmuje tylko część wytycznych (bezpieczeństwo, prywatność, działanie, rzetelność). Według [strony wytycznych](https://developer.apple.com/app-store/review/guidelines/) nie należą do niej 5.2.x ani 4.1. Należy do niej 2.3.1: żadnych ukrytych funkcji.

## Bramki

| Bramka | Warunek zakończenia | Właściciel | Dowód | Stan |
|---|---|---|---|---|
| G0 — rozdzielenie projektu | Kopia z osobnym ID, bez edycji oryginału | Programista | Konfiguracja, hashe | ZAMKNIĘTA |
| G1 — ryzyka zaakceptowane | Ryzyka nieoficjalnego dostępu, marki i GPL spisane i przyjęte | Użytkownik | [09-RYZYKA.md](09-RYZYKA.md), decyzje D13–D14 | ZAMKNIĘTA 2026-09-16 |
| G2 — zgodność licencyjna | GPLv3 projektu, licencje komponentów w aplikacji, publiczny kod tej samej wersji | Programista + użytkownik | `LICENSE`, ekran licencji, URL repozytorium, tag Git | ZAMKNIĘTA po publikacji repozytorium (tag Git przy każdym wydaniu) |
| G3 — gotowość pod notaryzację | Prywatność (manifest, usuwanie danych, logi), zgodne opisy uprawnień, brak ukrytych funkcji, stany błędów | Programista | Przegląd, testy | CZĘŚCIOWO: PRIV-01/03, SEC-01 zrobione; UX-01 otwarte |
| G4 — testy wydania | Scenariusze z `05` dla wybranego builda, w tym fizyczne | Użytkownik + programista | Raporty testów | OTWARTA |
| G5 — konta i umowy | Płatne konto Apple, Alternative Terms Addendum, rejestracja w AltStore PAL, hosting | Użytkownik | App Store Connect, token Marketplace | OTWARTA |
| G6 — notaryzacja i publikacja | Build notaryzowany, ADP opublikowany, źródło AltStore działa, instalacja z czystego iPhone’a | Użytkownik | Status Apple, test instalacji | OTWARTA |

## Kolejność

1. **Kod (programista):** UX-01 (stany uprawnień, sieci i konta), BLE-01 (uczciwe opisy dzwonienia), przegląd opisów uprawnień.
2. **Strona:** polityka prywatności i opis (np. GitHub Pages w repozytorium).
3. **Konta (użytkownik):** kroki 1–3 z [06-ALTSTORE-PAL.md](06-ALTSTORE-PAL.md).
4. **Testy:** macierz z `05` na buildzie Release podpisanym do dystrybucji.
5. **Notaryzacja, ADP, źródło AltStore, instalacja testowa.**

## Decyzje właściciela do zapisania

- [x] Nazwa: **Tagpin**; ikona bez zmian.
- [x] Kanał: AltStore PAL w UE; licencja GPLv3.
- [x] Wydawca: **mintstudio** (działalność mintstudio Jakub Koncewicz); status przedsiębiorcy (DSA) do zadeklarowania w App Store Connect.
- [x] Ostateczny Bundle ID: `pl.mintstudio.tagpin`.
- [x] Kod: https://github.com/darthkubox/Tagpin. [ ] Hosting ADP i strony (np. GitHub Releases / Pages).
- [x] Kontakt: kontakt@mintstudio.pl.
- [ ] Aplikacja bezpłatna (zalecane — brak płatności w kodzie).
- [ ] Języki opisu (PL, opcjonalnie EN).
