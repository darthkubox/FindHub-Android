# Tagpin: przegląd projektu i wydania (PL)

Stan: **16 września 2026. Kod gotowy do dalszych prac nad wydaniem; aplikacji nie notaryzowano ani nie opublikowano.**

W tym folderze jest kopia natywnej aplikacji iOS przygotowywana do publicznej dystrybucji. Oryginał w `../MotoHub` nadal służy do codziennego użytku i nie jest zmieniany.

## Kierunek wydania (decyzja użytkownika z 2026-09-16)

- **Nie App Store.** Aplikacja korzysta z nieoficjalnego dostępu do Find Hub, na który Google nie wydaje zgody. Punkt 5.2.2 wytycznych Apple takiej zgody wymaga, więc App Review aplikację odrzuci. Przygotowania do App Store są w [docs/archiwum](archiwum/).
- **AltStore PAL w UE.** Dystrybucja przez alternatywny sklep na podstawie DMA. Apple sprawdza aplikację wyłącznie w ramach notaryzacji: bezpieczeństwo, prywatność, poprawne działanie i rzetelny opis. Punkty 5.2.x i 4.1 w notaryzacji nie obowiązują.
- **Otwarty kod na GPLv3.** Część logiki jest portem [GoogleFindMyTools](https://github.com/leonboe1/GoogleFindMyTools) (GPLv3).
- **Uczciwy opis.** Aplikacja jest niezależnym, nieoficjalnym klientem. Ryzyka są opisane w [docs/09-RYZYKA.md](09-RYZYKA.md).

## Od czego zacząć

1. [Plan i bramki wydania](01-PLAN-WYDANIA.md)
2. [Ryzyka](09-RYZYKA.md)
3. [Instrukcja AltStore PAL i notaryzacji](06-ALTSTORE-PAL.md)
4. [Backlog](03-BACKLOG-TECHNICZNY.md), [prywatność](04-PRYWATNOSC-I-BEZPIECZENSTWO.md), [testy](05-TESTY-I-KRYTERIA.md)
5. [Stan i dowody](07-STAN-I-DOWODY.md)

## Zawartość

| Ścieżka | Zawartość |
|---|---|
| `App/project.yml` | Źródło konfiguracji XcodeGen; projekt `App/Tagpin.xcodeproj` jest generowany |
| `App/Sources`, `App/Resources`, `App/Tests`, `App/Proto` | Kod, zasoby (w tym `PrivacyInfo.xcprivacy` i `Licenses/`), testy, definicje protokołu |
| `App/Config` | `Base.xcconfig` w repozytorium; lokalny `Local.xcconfig` z zespołem podpisującym jest pomijany przez Git |
| `LICENSE`, `NOTICE`/`NOTICE.pl`, `Legal/` | GPLv3 projektu, podsumowanie autorów i licencje komponentów |
| `Scripts/check_local.sh` | Testy offline i opcjonalny build Release bez podpisu |
| `docs/` | Plan, instrukcje, szablony, dowody |

## Uruchomienie lokalne

```bash
cp App/Config/Local.xcconfig.example App/Config/Local.xcconfig   # wpisz swój DEVELOPMENT_TEAM
xcodegen generate --spec App/project.yml
bash Scripts/check_local.sh
bash Scripts/check_local.sh --build
```

Wymagany jest Xcode 26 lub nowszy; minimalna wersja systemu to iOS 17. `check_local.sh` niczego nie podpisuje, nie wysyła i nie instaluje. Testy offline nie łączą się z Google.

## Co różni tę kopię od MotoHub

- Nazwa „Tagpin”, moduł `Tagpin`, Bundle ID `pl.mintstudio.tagpin`, osobny Keychain i identyfikator zadania w tle.
- Funkcja „Usuń dane tego konta z telefonu” w Ustawieniach.
- Ekran „Licencje i kod źródłowy”, manifest prywatności, nazwy urządzeń ukryte w logach systemowych.
- Poprawki z MotoHub przeniesione 2026-09-16: wysokość panelu 124 pt, szczegóły urządzenia bez linii statusu. Kolejne zmiany w oryginale nie przechodzą tu automatycznie.

Obecna ikona i nazwa „Tagpin” zostały zaakceptowane przez użytkownika (2026-09-16).

Wydawca: **mintstudio** (mintstudio Jakub Koncewicz), kontakt@mintstudio.pl. Repozytorium: https://github.com/darthkubox/Tagpin.
