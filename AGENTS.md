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
- `Resources/Assets.xcassets/AppLogo.imageset/app_logo.png` to pomniejszona (512 px) kopia `AppIcon.appiconset/icon_1024.png` dla ekranu logowania; po regeneracji ikony odtwórz ją: `sips -Z 512 …/icon_1024.png --out …/app_logo.png`.
- Ekrany wypychane w `NavigationStack` zakładek nie dziedziczą `safeAreaInset` powłoki, więc ich dół chował się pod paskiem nawigacji. Każdy taki ekran kończy łańcuch modyfikatorów `.clearsTabBar()` (rezerwa z `EnvironmentValues.tabBarReserve`); pilnuje tego `ScrollInsetTests`. Dodając nowy ekran wypychany z zakładki, dodaj też `.clearsTabBar()`.
- Wszystkie wysuwane okna (arkusze) wyglądają jak szuflada na mapie: prezentacja `.m3Sheet()` (tło surface, rogi 28 pt, bez systemowego uchwytu), nagłówek `M3SheetHeader` przez `.m3SheetRoot(tytuł) { zamknij }` zamiast paska nawigacji i „Gotowe”, listy `.m3SheetList(scheme)` z wierszami `M3.background`. Nowy arkusz buduj tak samo.
- Odstępy (siatka 4/8 pt): szuflady — nagłówek 20 pt od krawędzi i 12 pt pod tytułem, treść i karty 16 pt od krawędzi, 10 pt między kartami, 12 pt wewnątrz wierszy; listy w arkuszach — wiersze min. 52 pt, 24 pt między sekcjami. Nowe ekrany trzymaj tych wartości.
- Błędy po zalogowaniu pokazuj przez `AppModel.show(AppIssue.from(error, context:))` — karta `IssueBanner` w szufladach z akcją (ponów, zaloguj ponownie, ustawienia, odblokuj klucze). `model.status` jest widoczny tylko na ekranie logowania. Nowe typy błędów mapuj w `AppIssue.from` i dopisz przypadek do `AppIssueTests`.
- Wylogowanie i usunięcie danych konta wymagają potwierdzenia alertem „Czy na pewno…”.
- Okna Google (logowanie, odblokowanie kluczy) są pełnoekranowe (`fullScreenCover`), bo w arkuszu rysowanie wzoru odblokowania ściągało okno w dół. Nie wracaj do `.sheet`.
- Polityka prywatności i warunki korzystania: `App/Resources/Legal/*.md` (te same pliki w aplikacji i pod publicznym URL). Każda zmiana przepływu danych, uprawnień lub funkcji wymaga aktualizacji polityki; istotna zmiana dokumentów wymaga podbicia `LegalDocument.currentVersion` i daty/wersji w nagłówku.
- Zachowaj architekturę bez własnego backendu.
- Kod jest publikowany: nie umieszczaj w repozytorium tokenów, kluczy E2EE, haseł, certyfikatów, UDID, e-maili, ścieżek domowych ani danych lokalizacji. Nie loguj nazw urządzeń ani współrzędnych jako `.public`.
- Zachowaj nagłówki autorów i aktualizuj `App/Resources/Licenses/ACKNOWLEDGEMENTS-pl.txt` oraz `ACKNOWLEDGEMENTS-en.txt` przy dodaniu komponentu.
- **Języki (polecenie użytkownika 2026-09-17):** interfejs PL, EN, DE, FR, ES, IT w `App/Resources/Localizable.xcstrings` (klucze po polsku, język zapasowy EN przez `DEVELOPMENT_LANGUAGE: en`). Każdy nowy tekst UI dodaj z tłumaczeniami wszystkich języków; komunikaty spoza widoków SwiftUI twórz przez `String(localized:)`, a parametry pomocniczych widoków typuj jako `LocalizedStringKey`. Dokumenty prawne, licencje, README, NOTICE i opisy sklepu utrzymuj zawsze po polsku i po angielsku, w tej samej wersji. `LocalizationTests` i `LegalTests` pilnują kompletności.
- Nie uznawaj sukcesu kompilacji za dowód notaryzacji, fizycznego działania taga ani zgodności prawnej. Dokumentuj pracę i dowody w `docs/07-STAN-I-DOWODY.md`.
- Zmiany funkcjonalne waliduj testami z `App/Scripts` i XCTest; pełna macierz jest w `docs/05-TESTY-I-KRYTERIA.md`.
- Nie tworzysz zdalnych repozytoriów, kont, umów ani wysyłek do Apple/AltStore bez wyraźnego polecenia użytkownika.
