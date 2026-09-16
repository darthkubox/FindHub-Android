# Praca nad wydaniem FindHub Android

Ten katalog jest oddzielnym projektem. Użytkownik wyraźnie polecił nie zmieniać oryginału.

- Wszystkie zmiany tego wydania wykonuj wewnątrz tego folderu. Nie zmieniaj `../MotoHub`, `../CLAUDE.md`, pozostałych dokumentów źródła ani `../GoogleFindMyTools`. Poprawki z oryginału przenoś świadomie i odnotuj w `docs/07-STAN-I-DOWODY.md`.
- Kanał wydania: **AltStore PAL w UE z notaryzacją Apple**, kod na **GPLv3** (decyzja użytkownika 2026-09-16). App Store nie jest celem; materiały App Store leżą w `docs/archiwum/`.
- Nie dodawaj ukrytych funkcji, przełączników „na czas recenzji” ani trybów zmieniających działanie po notaryzacji (Apple 2.3.1 obowiązuje także w notaryzacji). Opis i działanie muszą być zgodne.
- Aplikacja jest nieoficjalnym klientem Find Hub. W UI, opisie i dokumentacji nie sugeruj powiązania z Google ani Motorola.
- `App/project.yml` jest źródłem konfiguracji; regeneruj XcodeGen zamiast ręcznie zmieniać project.pbxproj. Zespół podpisujący ustawiaj tylko w nieśledzonym `App/Config/Local.xcconfig`.
- Schemat i projekt to `FindHub Android`, a techniczny moduł to `FindHubAndroid`. Nazwa produktu to dokładnie „FindHub Android”; obecna ikona zostaje bez zmian (decyzje użytkownika 2026-09-16).
- Wydawca: **mintstudio** (mintstudio Jakub Koncewicz), kontakt@mintstudio.pl; Bundle ID `pl.mintstudio.findhubandroid`; publiczne repozytorium https://github.com/darthkubox/FindHub-Android (commity z adresu kontakt@mintstudio.pl). Nowe pliki źródłowe dostają nagłówek SPDX `GPL-3.0-or-later`, a kod portowany — źródło, autora i licencję; aktualizuj też `NOTICE` i tabelę w `README.md`.
- Logo mintstudio nie jest objęte GPL.
- Polityka prywatności i warunki korzystania: `App/Resources/Legal/*.md` (te same pliki w aplikacji i pod publicznym URL). Każda zmiana przepływu danych, uprawnień lub funkcji wymaga aktualizacji polityki; istotna zmiana dokumentów wymaga podbicia `LegalDocument.currentVersion` i daty/wersji w nagłówku.
- Zachowaj architekturę bez własnego backendu.
- Kod jest publikowany: nie umieszczaj w repozytorium tokenów, kluczy E2EE, haseł, certyfikatów, UDID, e-maili, ścieżek domowych ani danych lokalizacji. Nie loguj nazw urządzeń ani współrzędnych jako `.public`.
- Zachowaj nagłówki autorów i aktualizuj `App/Resources/Licenses/ACKNOWLEDGEMENTS.txt` przy dodaniu komponentu.
- Nie uznawaj sukcesu kompilacji za dowód notaryzacji, fizycznego działania taga ani zgodności prawnej. Dokumentuj pracę i dowody w `docs/07-STAN-I-DOWODY.md`.
- Zmiany funkcjonalne waliduj testami z `App/Scripts` i XCTest; pełna macierz jest w `docs/05-TESTY-I-KRYTERIA.md`.
- Nie tworzysz zdalnych repozytoriów, kont, umów ani wysyłek do Apple/AltStore bez wyraźnego polecenia użytkownika.
