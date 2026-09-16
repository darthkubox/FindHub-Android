# Metadane wydania (App Store Connect i źródło AltStore PAL) — ROBOCZE

Pola wersji w App Store Connect uzupełnia się także przy notaryzacji; opis w źródle AltStore: [altstore-source.json](altstore-source.json). Opis musi mówić, że aplikacja jest nieoficjalnym klientem niepowiązanym z Google (zob. [09-RYZYKA.md](../09-RYZYKA.md)).

Nazwa jest ustalona: **FindHub Android**. Pozostałe metadane wymagają zamknięcia G1/G2 oraz potwierdzenia zakresu funkcji i wyników testów.

## Dane podstawowe

| Pole | Do ustalenia |
|---|---|
| Nazwa publiczna | FindHub Android |
| Podtytuł | [KRÓTKI, PRAWDZIWY OPIS] |
| Język podstawowy / lokalizacje | Angielski (podstawowy); lokalizacje: polski, niemiecki, francuski, hiszpański, włoski — opis i słowa kluczowe dla każdej |
| Kategoria | [WYBRAĆ WEDŁUG GŁÓWNEJ FUNKCJI] |
| Bundle ID / SKU | `pl.mintstudio.findhubandroid` / [SKU] |
| Wersja i build | [DOKŁADNY KANDYDAT] |
| Support URL / Privacy Policy URL | https://github.com/darthkubox/FindHub-Android (support: Issues, kontakt@mintstudio.pl) / https://github.com/darthkubox/FindHub-Android/blob/main/App/Resources/Legal/polityka-prywatnosci.md |
| Copyright / wydawca | © 2026 mintstudio Jakub Koncewicz / mintstudio |
| Kraje / model płatności | [ ] |

## Szkic opisu funkcji

FindHub Android pozwala przeglądać ostatnie dostępne lokalizacje kompatybilnych urządzeń powiązanych z Twoim kontem [NAZWA USŁUGI — zgodnie z uprawnieniem].

Zakres do pozostawienia tylko po przetestowaniu:

- mapa z ostatnią znaną pozycją, czasem i dokładnością raportu;
- lokalna historia odczytów, notatki i zapisane miejsca;
- funkcje Bluetooth i powiadomienia zależne od wspieranego taga oraz uprawnień systemowych;
- [INNE WYŁĄCZNIE POTWIERDZONE FUNKCJE].

Wymagania: [KONTO, INTERNET, MODELE, WERSJE OS, WCZEŚNIEJSZE PAROWANIE].

Ograniczenia: raporty mogą być opóźnione; historia obejmuje odczyty zebrane przez aplikację; działanie w tle i powiadomienia zależą od iOS i akcesorium. Nie przedstawiać aplikacji jako gwarantowanego zabezpieczenia przed kradzieżą. [DODATKOWE RZECZYWISTE OGRANICZENIA].

Status integracji/niezależnego wydawcy: [SFORMUŁOWANIE ZGODNE Z POSIADANYMI PRAWAMI]. Sam disclaimer nie daje uprawnień do Google ani znaków.

## Keywords i długości

Dobierać własne słowa opisujące funkcje, bez upychania cudzych marek. Sprawdzić limity każdego pola w aktualnym App Store Connect; keywords mają limit wyrażony w bajtach, co ma znaczenie dla polskich znaków. [Referencja pól Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).

## Plan screenshotów

1. Mapa: kilka syntetycznych tagów, widoczny czas odczytu.
2. Szczegóły: dokładność, ostatni raport i dostępne akcje.
3. Historia: autentyczny wygląd funkcji na danych demonstracyjnych; bez sugerowania ciągłego GPS.
4. Miejsca/alerty: dopiero po testach fizycznych i z uczciwym opisem.
5. Ustawienia/prywatność: tylko wdrożone opcje.

Nie używać danych z prywatnego konta ani grafiki referencyjnej Google. Zrzuty muszą odpowiadać finalnemu buildowi i wymaganym urządzeniom. Nie reklamować niezaimplementowanego procentu baterii, parowania nowych tagów lub UWB.

## Informacje do recenzji

Kontakt: [ ]
Konto demo / opis jawnego demo: [HASŁO WYŁĄCZNIE W BEZPIECZNYM POLU APP STORE CONNECT]
Obsługiwane tagi i sposób ich zapewnienia: [ ]
Dowód praw do usługi i kodu: [IDENTYFIKATOR DOKUMENTU]

## Uznanie autorów w opisie

Każdy publiczny opis (App Store Connect, źródło AltStore, strona) zawiera: informację o braku powiązania z Google/Motorola/Apple, licencję GPLv3 z linkiem do kodu i listę projektów, z których korzysta aplikacja (GoogleFindMyTools — Leon Böttger, firebase-messaging, gpsoauth, http_ece, micro-ecc, Chromium, SwiftProtobuf), z odesłaniem do pełnych licencji.

## Opis (EN, podstawowy)

FindHub Android lets you view the latest known locations of compatible devices linked to your Google Find Hub account — on your iPhone. It is an independent, unofficial app published by mintstudio and is not affiliated with Google. Requires a Google account and trackers already paired on Android. Reports can be delayed; background alerts depend on iOS. Open source under GPLv3.
