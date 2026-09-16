# Instrukcja przygotowania i publikacji w App Store

Stan sprawdzenia źródeł: 2026-09-16. Procedura do wykonania w przyszłości, po zamknięciu właściwych bramek. Nie wykonano poniżej opisanych operacji na koncie Apple.

## 1. Konto i rola wydawcy

- [ ] Potwierdzić aktywne członkostwo Apple Developer Program. Sam Team ID w projekcie i możliwość instalacji developerskiej nie są dowodem gotowości konta do publikacji.
- [ ] Wybrać wydawcę indywidualnego lub organizację i sprawdzić nazwę sprzedawcy prezentowaną w sklepie.
- [ ] Zapewnić właściwe role App Store Connect; tylko uprawnione osoby akceptują umowy.
- [ ] Sprawdzić najnowsze umowy. Przy odpłatnej dystrybucji/zakupach uzupełnić umowy handlowe, bankowość i podatki odpowiednie dla modelu.
- [ ] Przy dystrybucji w UE zadeklarować status trader/non-trader zgodnie z rzeczywistą działalnością. Gdy dotyczy, przejść weryfikację danych kontaktowych i uwzględnić ich publiczne wyświetlanie.

Standardowe członkostwo kosztuje 99 USD rocznie lub lokalny odpowiednik; potwierdzić cenę na koncie. [Program Apple](https://developer.apple.com/programs/enroll/). Status przedsiębiorcy nie wynika wyłącznie z tego, czy aplikacja jest bezpłatna. [Instrukcja DSA](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).

## 2. Ostateczna tożsamość aplikacji

- [x] Publiczna nazwa: **FindHub Android** — zatwierdzona przez użytkownika.
- [ ] Zweryfikować dostępność i prawa do użycia wybranej nazwy w ramach przygotowania publikacji.
- [ ] Zatwierdzić finalny Bundle ID. Obecny `com.kuba.motohub.appstorecandidate` jest roboczy i odrębny od prototypu; nie zarejestrowano go w tej pracy.
- [ ] Jeśli zmieniamy ID: poprawić `App/project.yml`, usługę w `Keychain.swift`, identyfikator w `GuardianBackground.swift`, a następnie wygenerować Info.plist/XcodeGen. Testować jako osobną aplikację, bez domyślnej migracji danych.
- [ ] W portalu Apple zarejestrować jawny App ID i tylko rzeczywiście używane capabilities.
- [ ] W App Store Connect utworzyć **New App**, wybrać iOS, nazwę, język podstawowy, ten sam Bundle ID, własny unikalny SKU i dostęp zespołu. SKU nie jest nazwą dla klientów.
- [ ] Sprawdzić, czy nie użyto identyfikatora starej aplikacji. Nie tworzyć rekordów „na próbę” przed decyzją o tożsamości.

[Tworzenie rekordu](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app), [przygotowanie projektu do dystrybucji](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution).

## 3. Narzędzia i build

Aktualny wymóg wysyłki to Xcode 26+ i SDK iOS 26+; może się zmienić przed wydaniem. Minimum systemu użytkownika iOS 17 pozostaje oddzielną decyzją. [Wymagania SDK](https://developer.apple.com/news/upcoming-requirements/).

- [ ] Wybrać zatwierdzony stan źródeł i zamrozić zależności w `Package.resolved`.
- [ ] Ustawić wersję marketingową oraz nowy, niewykorzystany numer builda.
- [ ] Zregenerować projekt, jeśli zmieniono `project.yml`.
- [ ] Uruchomić testy z dokumentu 05 dla tego stanu kodu.
- [ ] Przejrzeć Release pod kątem logów, środowisk testowych, fake data i deklaracji prywatności.
- [ ] Sprawdzić właściwy zespół w Signing & Capabilities; nie eksportować prywatnych kluczy do repozytorium.

W Xcode otworzyć `App/FindHub Android.xcodeproj`, wybrać schemat `FindHub Android` i urządzenie ogólne iOS, następnie **Product → Archive**. Alternatywny przyszły command line, uruchamiany z katalogu nowego projektu:

```bash
xcodebuild -project "App/FindHub Android.xcodeproj" -scheme "FindHub Android"   -configuration Release -destination 'generic/platform=iOS'   -derivedDataPath /tmp/findhub-android-appstore-archive-build   -archivePath /tmp/FindHubAndroid.xcarchive archive
```

Archiwizacja wymaga działającego podpisu dystrybucyjnego/automatycznego zarządzania podpisem. Jeśli Xcode wymaga provisioningu, skonfigurować go świadomie na właściwym koncie. Nie używać `CODE_SIGNING_ALLOWED=NO` do archiwum przeznaczonego na wysyłkę.

W Organizer:

1. Sprawdzić Bundle ID, wersję, build i zespół.
2. Skontrolować zawartość aplikacji, manifesty prywatności, ikonę 1024×1024 bez alpha i finalne opisy uprawnień.
3. Użyć walidacji aplikacji w dostępnej ścieżce dystrybucji App Store Connect.
4. Usunąć błędy i ocenić ostrzeżenia. Ostrzeżenie nie jest automatycznie nieistotne.
5. Przejść **Distribute App → App Store Connect** i przesłać zaakceptowane archiwum.
6. Poczekać na processing i sprawdzić wiadomości Apple oraz status builda. Zapis „Upload succeeded” nie oznacza akceptacji recenzji.

Zachować archiwum i symbole dSYM w prywatnym archiwum wydania. Nie przechowywać ich w zwykłym repozytorium źródeł.

## 4. Deklaracje wymagające rzeczywistych ustaleń

- [ ] **App Privacy**: wypełnić z audytu przepływów danych, nie z ogólnego hasła „bez backendu”.
- [ ] **Privacy Policy URL**: działający HTTPS, publiczny dostęp bez konta, identyczna treść po wejściu z aplikacji.
- [ ] **Szyfrowanie**: przejść ankietę eksportową; dostarczyć wymagane dokumenty lub uzasadnić wyjątek. Dotyczy także buildów testowych.
- [ ] **Age Rating**: odpowiedzieć zgodnie z rzeczywistymi funkcjami, w tym zewnętrznym dostępem webowym; nie wpisywać z góry 4+.
- [ ] **Content Rights**: deklarować wyłącznie prawa, które mamy i możemy udokumentować.
- [ ] **Accessibility**: jeśli podajemy dostępność funkcji w etykietach sklepu, oprzeć odpowiedzi na testach.
- [ ] **Kraje i zgodność lokalna**: ograniczyć do sprawdzonego zakresu; dodatkowe wymagania krajowe ocenić przed rozszerzeniem dystrybucji.

[Zarządzanie App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), [szyfrowanie](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance), [przygotowanie zgłoszenia](https://developer.apple.com/app-store/submitting/).

## 5. Materiały sklepu

Użyć [szablonu metadanych](../templates/METADANE-SKLEPU.md), usunąć wszystkie oznaczenia robocze i dostosować treść do rzeczywistego zakresu.

- [ ] Nazwa, podtytuł, opis, keywords, kategoria, copyright i kontakt wsparcia.
- [ ] Opis jasno informuje, że tagi muszą być wcześniej skonfigurowane zgodnie z wymaganiami usługi; parowanie Android i brak UWB nie mogą być ukryte.
- [ ] Brak obietnic bieżącej pozycji, procentu baterii lub gwarantowanego alarmu, jeśli ich nie zapewniamy.
- [ ] Support URL prowadzi do działającej strony z kontaktem i instrukcjami. Bez placeholderów.
- [ ] Screenshoty z finalnego builda na syntetycznych danych, bez prywatnych e-maili, miejsc i urządzeń użytkownika.
- [ ] Sprawdzić wymagane zestawy rozmiarów dla faktycznie wspieranych urządzeń w App Store Connect. Dla obecnego targetu jest to iPhone; dodanie iPada wymaga ponownego przejrzenia zestawów.
- [ ] Nie publikować obrazu referencyjnego Google ani nie sugerować oficjalnego partnerstwa.
- [ ] Sprawdzić języki, wybrane kraje, cenę oraz dostępność zgodnych aplikacji iPhone na Mac/Apple Vision Pro; nie zostawiać nieprzetestowanych platform tylko dlatego, że są zaznaczone domyślnie.

Proponowana sekwencja screenshotów: mapa i tagi → szczegóły lokalizacji → historia z lukami → miejsca i alerty → prywatność/ustawienia. To koncepcja materiałów, nie wykonane screenshoty. [Specyfikacja rozmiarów](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [wymagania pól](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).

## 6. TestFlight

1. Rozwiązać błędy processingu i deklaracje builda.
2. Przygotować informacje beta i rzeczywisty kontakt.
3. Dodać uprawnionych wewnętrznych testerów. Nie nadawać roli zespołowej osobie wyłącznie dla obejścia review.
4. Dla testów zewnętrznych przygotować grupę, informacje i Beta App Review, gdy wymagany.
5. Przekazać zakres testów i sposób zgłaszania defektów.
6. Przeprowadzić testy dystrybucyjnego builda, zebrać wynik i usunąć błędy.

Nie zakładamy, że wysyłka do TestFlight rozstrzyga zgodność z Google lub licencjami. [Instrukcja testerów zewnętrznych](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).

## 7. App Review

- [ ] Do wersji przypiąć dokładnie przetestowany build.
- [ ] Dodać kontakt oraz [notatki dla recenzenta](APP-REVIEW-NOTES.md).
- [ ] Przygotować pełny dostęp testowy, opis tagów, autoryzacji i kluczy. Ustalić sposób przejścia MFA bez prywatnego telefonu właściciela.
- [ ] Jeśli konto demo nie jest możliwe, uzgodnić adekwatny pełny tryb demo; nie zakładać, że sam film zastąpi dostęp.
- [ ] Wyjaśnić wymagane tryby tła, ograniczenia lokalizacji, integrację z Google oraz ewentualny wyjątek klienta zewnętrznej usługi dla logowania.
- [ ] Dołączyć potwierdzenia uprawnień/licencji, jeśli wymagane; poufne dokumenty przekazywać odpowiednim kanałem.
- [ ] Zaktualizować wszystkie czerwone pola/uwagi w App Store Connect.
- [ ] Wybrać ręczne wydanie po zatwierdzeniu.
- [ ] Dodać wersję do zgłoszenia i wykonać końcowe wysłanie do review — samo „Ready for Review” nie oznacza, że zgłoszenie zostało wysłane.

[Przesyłanie aplikacji do recenzji](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).

## 8. Odrzucenie, zatwierdzenie i premiera

Przy odrzuceniu zapisać konkretny punkt, pytanie i build; przygotować merytoryczną odpowiedź z dowodem lub poprawić aplikację. Nie wysyłać identycznego builda bez wyjaśnienia i nie ukrywać problematycznej funkcji przed Apple.

Po zatwierdzeniu sprawdzić działanie strony sklepu, cenę, kraje i support, następnie wykonać ręczne wydanie. Pobrać aplikację z App Store na czystym urządzeniu i sprawdzić logowanie oraz podstawową ścieżkę. Zapisz datę, build i osobę decydującą o publikacji.

## 9. Utrzymanie

- Wyznaczyć osobę odbierającą zgłoszenia i śledzącą zmiany autoryzacji/API Google oraz wymagań Apple.
- Przy awarii integracji przygotować komunikat dla klientów; nie obiecywać niezweryfikowanego terminu naprawy.
- Nie ma prostego „cofnięcia pliku” w sklepie: poprawkę przygotowuje się jako nowy build/wersję. W razie potrzeby ograniczyć dostępność nowych pobrań, pamiętając o istniejących instalacjach.
- Aktualizować politykę, manifest i etykiety danych przy zmianie przepływów.
- Zachowywać dowody praw/licencji, testów i podpisane archiwa każdej wersji.
