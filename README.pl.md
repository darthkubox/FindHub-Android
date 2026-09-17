<p align="center">
  <img src="docs/assets/tagpin-icon.png" width="128" height="128" alt="Ikona Tagpin">
</p>

<h1 align="center">Tagpin</h1>

<p align="center"><a href="README.md">English</a> · <b>Polski</b></p>

<p align="center">
  Nieoficjalny natywny klient iOS dla lokalizatorów Google Find Hub — mapa, historia, miejsca i dzwonienie przez Bluetooth, wszystko na telefonie.<br>
  <b>Niepowiązany z Google.</b> Licencja GPLv3.
</p>

---

> [!IMPORTANT]
> **Tagpin to niezależny, nieoficjalny projekt.** Nie jest powiązany z Google LLC, Motorola ani Apple Inc., nie jest przez nie wspierany ani zatwierdzony. Google nie udostępnia publicznego API Find Hub; aplikacja łączy się z usługami Google tak, jak robi to projekt [GoogleFindMyTools](https://github.com/leonboe1/GoogleFindMyTools), oparty na analizie protokołu. Google może to w każdej chwili zmienić lub zablokować, a korzystanie z nieoficjalnego klienta może naruszać warunki Google. Korzystasz na własne ryzyko.

## Co robi

Tagpin pozwala użytkownikom iPhone’a zobaczyć tagi Find Hub (np. Motorola moto tag) **sparowane wcześniej na telefonie z Androidem** z ich kontem Google.

- **Mapa** tagów i Twojej pozycji, z grupowaniem, czasem raportu, dokładnością i odległością.
- **Lokalizowanie** taga przez sieć Find Hub; raporty są odszyfrowywane **na iPhonie** (AES-GCM / SECP160r1 + AES-EAX).
- **Lokalna historia z 7 dni** z uczciwie pokazanymi przerwami (bez zmyślonych punktów trasy).
- **Miejsca**: dom, praca i inne obszary, z lokalnymi alertami, gdy świeże raporty potwierdzą, że tag opuścił obszar.
- **Dzwonienie** do najbliższego taga przez Bluetooth, standardowym dźwiękiem DULT.
- **Alerty o oddaleniu przez Bluetooth** po potwierdzonym połączeniu z tagiem.
- **Ustawienia powiadomień**: włączanie alertów miejsc i utraty kontaktu, ukrywanie nazw na ekranie blokady, powiadomienie testowe.
- Własne nazwy, ikony, zdjęcia i notatki, wiele kont Google, jasny i ciemny motyw.
- **Usuwanie danych konta z telefonu** w Ustawieniach.
- **Tryb demonstracyjny** na ekranie logowania: wszystkie ekrany na przykładowych danych, bez konta Google i bez łączenia się z Google czy tagami.

### Ograniczenia

- Bez parowania nowych tagów (paruj najpierw na Androidzie), bez precyzyjnego wyszukiwania UWB, bez poziomu baterii.
- Raporty mogą być opóźnione; działanie w tle i alerty zależą od iOS i nie są gwarantowane.
- iOS 17 lub nowszy, tylko iPhone.

## Prywatność

Projekt **nie ma żadnego serwera**. Tokeny i klucze szyfrowania zostają w pęku kluczy (Keychain) iPhone’a. Historia, miejsca i notatki są zapisywane lokalnie i wyłączone z kopii zapasowej; własne nazwy, ikony i zdjęcia urządzeń trafiają do zwykłego magazynu aplikacji. Aplikacja łączy się z Google (logowanie, lista urządzeń, raporty lokalizacji) i Apple (mapy) wyłącznie po to, by działać. Nic nie trafia do mintstudio.

## Dokumenty prawne

| Dokument | Polski | English |
|---|---|---|
| Polityka prywatności | [polityka-prywatnosci.md](App/Resources/Legal/polityka-prywatnosci.md) | [privacy-policy.md](App/Resources/Legal/privacy-policy.md) |
| Warunki korzystania | [warunki-korzystania.md](App/Resources/Legal/warunki-korzystania.md) | [terms-of-use.md](App/Resources/Legal/terms-of-use.md) |
| Licencje i podziękowania | [ACKNOWLEDGEMENTS-pl.txt](App/Resources/Licenses/ACKNOWLEDGEMENTS-pl.txt) | [ACKNOWLEDGEMENTS-en.txt](App/Resources/Licenses/ACKNOWLEDGEMENTS-en.txt) |
| Przegląd licencji | [Legal/README.pl.md](Legal/README.pl.md) | [Legal/README.md](Legal/README.md) |

Wszystkie dokumenty są dostępne w aplikacji (**Ustawienia → Informacje prawne**) i trzeba je zaakceptować przed logowaniem. Aplikacja uruchomiona po polsku pokazuje wersje polskie, w pozostałych językach — angielskie; w razie rozbieżności rozstrzyga wersja polska w zakresie dopuszczalnym przez prawo. W skrócie: aplikacja jest wolnym oprogramowaniem GPLv3 bez gwarancji; korzystaj z niej tylko z własnym kontem Google i urządzeniami, nigdy do śledzenia innych osób; mintstudio nie otrzymuje żadnych danych osobowych.

## Języki

Interfejs jest dostępny po **polsku, angielsku, niemiecku, francusku, hiszpańsku i włosku** i dopasowuje się do języka iPhone’a. Pozostałe języki korzystają z wersji angielskiej. Tłumaczenia są w [`App/Resources/Localizable.xcstrings`](App/Resources/Localizable.xcstrings); poprawki od native speakerów są mile widziane.

## Instalacja

- **AltStore PAL (UE):** planowana. Aplikacja nie przeszła jeszcze notaryzacji; link do źródła AltStore pojawi się tutaj po publikacji.
- **Nie w App Store:** Apple wymaga zgody usługi zewnętrznej (punkt 5.2.2 wytycznych), a Google jej nie udziela dla Find Hub.

### Budowanie ze źródeł

Wymaga Xcode 26+ i [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cp App/Config/Local.xcconfig.example App/Config/Local.xcconfig   # ustaw swój DEVELOPMENT_TEAM
xcodegen generate --spec App/project.yml
open "App/Tagpin.xcodeproj"
bash Scripts/check_local.sh          # testy regresji offline, bez konta i sieci
```

## Autorzy i licencje

Tagpin powstał dzięki pracy autorów poniższych projektów. Pełne teksty licencji są w [`ACKNOWLEDGEMENTS-pl.txt`](App/Resources/Licenses/ACKNOWLEDGEMENTS-pl.txt) ([English](App/Resources/Licenses/ACKNOWLEDGEMENTS-en.txt)) oraz w aplikacji: **Ustawienia → Licencje i kod źródłowy**.

| Projekt | Autorzy | Licencja | Wersja | Zastosowanie |
|---|---|---|---|---|
| [GoogleFindMyTools](https://github.com/leonboe1/GoogleFindMyTools) | Leon Böttger (SEEMOO, TU Darmstadt) | GPL-3.0 | `d46e952` (2026-05-05) | Definicje protokołu oraz przeniesiona logika logowania, Nova, Spot, kluczy i odszyfrowania raportów |
| [firebase-messaging](https://github.com/sdb9696/firebase-messaging) | Matthieu Lemoine, Steven Beth | MIT | z GoogleFindMyTools `d46e952` | Rejestracja FCM i połączenie push MCS (port) |
| [gpsoauth](https://github.com/simon-weber/gpsoauth) | Simon Weber | MIT | 2.0.0 | Wymiana tokenów konta Google (port) |
| [encrypted-content-encoding](https://github.com/web-push-libs/encrypted-content-encoding) | Martin Thomson | MIT | 1.2.1 | Odszyfrowanie Web Push `aesgcm` (port) |
| [micro-ecc](https://github.com/kmackay/micro-ecc) | Kenneth MacKay | BSD-2-Clause | `541b3a7` (2024-11-14) | Operacje na krzywej eliptycznej SECP160r1 (dołączona biblioteka) |
| [Chromium](https://chromium.googlesource.com/chromium/src/+/main/google_apis/gcm/protocol/) | The Chromium Authors | BSD-3-Clause | `main` | Definicje protobuf checkin i MCS |
| [SwiftProtobuf](https://github.com/apple/swift-protobuf) | Apple Inc. i współtwórcy | Apache-2.0 | 1.38.1 | Biblioteka protobuf (Swift Package) |

Wszystkie linki prowadzą do oryginalnych repozytoriów autorów. Wersje to dokładne rewizje, z których przeniesiono kod lub które dołączono; pliki micro-ecc sprawdzono bajt po bajcie (SHA-256) z repozytorium autora.

Materiały referencyjne: [specyfikacja akcesoriów Find Hub](https://developers.google.com/nearby/fast-pair/specifications/extensions/fmdn), [IETF DULT](https://datatracker.ietf.org/wg/dult/about/), [Material Design 3](https://m3.material.io).

Jeśli korzystasz z tej pracy naukowo, zacytuj też GoogleFindMyTools zgodnie z jego plikiem `CITATION.cff`.

### Licencja

Copyright © 2026 mintstudio Jakub Koncewicz.

Ten program jest wolnym oprogramowaniem: możesz go rozpowszechniać i modyfikować na warunkach **GNU General Public License v3.0** lub (według Twojego wyboru) dowolnej późniejszej wersji. Zobacz [`LICENSE`](LICENSE) i [`NOTICE.pl`](NOTICE.pl). Obowiązujący tekst licencji GPL jest w języku angielskim. Dokumentacja planowania projektu w `docs/` jest po polsku.

**Znaki towarowe.** Google, Find Hub i Android są znakami towarowymi Google LLC. Motorola i moto tag są znakami towarowymi Motorola Trademark Holdings, LLC. Apple i iPhone są znakami towarowymi Apple Inc. Nazwy służą wyłącznie opisaniu zgodności. Nazwa i logo mintstudio nie są objęte GPL; wszelkie prawa zastrzeżone.

## Kontakt

Zgłoszenia (Issues) i pull requesty są mile widziane. Kontakt: [kontakt@mintstudio.pl](mailto:kontakt@mintstudio.pl).

<p align="center">
  <a href="mailto:kontakt@mintstudio.pl">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="docs/assets/mintstudio-white.png">
      <img src="docs/assets/mintstudio.png" width="200" alt="mintstudio">
    </picture>
  </a>
</p>
