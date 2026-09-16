# Dostęp do Google, pochodzenie kodu i marka

To dokument rozstrzygnięć przed publiczną dystrybucją. Stan ustaleń: 2026-09-16. Odkryte fakty nie stanowią automatycznie ostatecznej kwalifikacji prawnej.

## Fakty w skopiowanym kodzie

| Element | Lokalizacja w `App/Sources` | Obserwacja |
|---|---|---|
| Logowanie | `LoginWebView.swift` | `WKWebView`, `accounts.google.com/EmbeddedSetup`, odczyt cookie `oauth_token` |
| Tokeny | `GoogleAuth.swift` | Wymiana na master/AAS token przez endpoint Android; identyfikatory `com.google.android.apps.adm` i `com.google.android.gms`, stały `client_sig` |
| Raporty i akcje | `Nova.swift` | Wywołania `android.googleapis.com/nova/nbe_list_devices` i `nbe_execute_action` |
| Klucze E2EE | `VaultUnlock.swift` | Strona `encryption/unlock/android`, wstrzyknięty JS bridge `mm.setVaultSharedKeys` |
| Transport | `FcmRegister.swift`, `McsClient.swift`, `HttpEce.swift` | Rejestracja i odbiór protokołu FCM/MCS zamiast własnego backendu/APNs |
| Kryptografia | `Crypto.swift`, `ForeignTrackerCryptor.swift`, `AesEax.swift`, `uECC` | Odszyfrowanie raportów i portowane elementy protokołu |

Nie wykazano tu używania prywatnych frameworków Apple. „Niepubliczny endpoint Google” to inna kwestia niż „prywatne API iOS”. Główne pytanie brzmi: czy Google dopuszcza taki dostęp i tożsamość klienta w dystrybuowanej aplikacji?

## Warunki i granice ustaleń

Google wymaga właściwej identyfikacji klienta OAuth i zakazuje autoryzacji w osadzonym, kontrolowanym przez aplikację user-agencie. Nasz odczyt cookie i korzystanie z identyfikatorów Google wymaga zastąpienia zatwierdzoną ścieżką lub wyraźnego uprawnienia obejmującego ten mechanizm. [OAuth 2.0 Policies](https://developers.google.com/identity/protocols/oauth2/policies).

Apple może oczekiwać dowodu, że korzystanie z usługi zewnętrznej jest dozwolone jej warunkami — §5.2.2. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#intellectual-property).

W przejrzanej dokumentacji publicznej znaleziono program i specyfikację **akcesoriów** Find Hub. Nie potwierdzają one istnienia ani licencji dla API odczytu lokalizacji przez niezależną aplikację iOS. Nie należy utożsamiać certyfikacji taga z uprawnieniem do stworzenia alternatywnego klienta konta Google. [Przewodnik Google dla partnerów](https://developers.google.com/nearby/fast-pair/landing-page-find-hub), [specyfikacja akcesoriów](https://developers.google.com/nearby/fast-pair/specifications/extensions/fmdn).

## Co dokładnie ustalić z Google

1. Czy niezależna aplikacja iOS może odczytywać lokalizacje własnych urządzeń użytkownika w Find Hub?
2. Jaki program, regulamin, umowa lub API to dopuszcza? Uzyskać link, wersję i zakres.
3. Jak zarejestrować własną tożsamość klienta; jakie scopes są dozwolone; czy potrzebna jest weryfikacja aplikacji?
4. Jak uzyskać i odświeżać tokeny bez używania tożsamości aplikacji Google?
5. Jak użytkownik ma autoryzować odszyfrowywanie lokalizacji i dostęp do kluczy E2EE?
6. Czy istnieje zatwierdzona alternatywa dla EmbeddedSetup i JS bridge strony Android?
7. Czy wspierane są: lista tagów, raporty sieciowe, raporty własne, zdalne dzwonienie, wiele kont?
8. Czy dopuszczona jest implementacja całkowicie na urządzeniu? Jakie są limity i zasady ruchu w tle?
9. Czy warunki obejmują publiczny App Store, TestFlight, wybrane kraje i odpłatną dystrybucję?
10. Jakich oznaczeń marki można użyć? Czy możemy przedstawić potwierdzenie Apple?

Gotowy szkic wiadomości: [szablon kontaktu](GOOGLE-PYTANIA.md). Nie został wysłany.

### Dowód zamknięcia G1

Zapisać w prywatnym archiwum korespondencję/umowę. W `07-STAN-I-DOWODY.md` wpisać datę, identyfikator dokumentu, zakres, warunki i osobę akceptującą. Nie publikować danych poufnych w repozytorium. Dla publicznych warunków zapisać konkretny URL i wersję oraz mapowanie uprawnień na wszystkie używane operacje.

## Audyt licencji — czynności

Repozytorium referencyjne `GoogleFindMyTools` ma GPLv3, a część komentarzy Swift wskazuje port kodu. Kopię tekstu zachowano w `Legal/GoogleFindMyTools-GPL-3.0.txt`. To nie jest decyzja o nadaniu tej licencji całemu nowemu projektowi.

1. Dla każdego pliku Swift/proto/C ustalić autora, źródło, commit/wersję i sposób wykorzystania.
2. Rozdzielić: bezpośredni port/kopię, niezależną implementację specyfikacji, generator i jego output, biblioteki oraz elementy samodzielnie napisane.
3. Porównać potencjalne porty z oryginałami, zachować wynik przeglądu i warunki źródłowych licencji.
4. Jeśli istnieje utwór zależny GPL, ustalić wszystkie obowiązki oraz zgodność konkretnego modelu dystrybucji z nimi. Nie zakładać, że publikacja źródeł sama rozwiąże wszystkie kwestie App Store.
5. Rozważyć uzyskanie alternatywnej licencji od wszystkich właściwych uprawnionych albo niezależną implementację dozwolonego interfejsu. Przepisanie przez AI ani zmiana nazw nie usuwa pochodzenia kodu.
6. Dodać prawidłowe teksty licencji i informacje o autorach do dystrybuowanej aplikacji oraz materiałów, zgodnie z warunkami komponentów.
7. Dopiero po rozstrzygnięciu wybrać licencję własnego produktu.

Tłumaczenie kodu na inny język nie usuwa obowiązków GPL; sama wiedza o protokole nie oznacza automatycznie, że każda niezależna implementacja jest utworem zależnym. [FAQ GNU: tłumaczenie kodu](https://www.gnu.org/licenses/gpl-faq.html#TranslateCode).

### Początkowa lista komponentów

| Składnik | Stan | Następna czynność |
|---|---|---|
| GoogleFindMyTools / fragmenty przeniesione do Swift | GPLv3 w repozytorium referencyjnym; zakres zależności nieustalony | Audyt plik po pliku |
| micro-ecc `App/Sources/uECC` | Nagłówki wskazują BSD 2-clause, Kenneth MacKay | Zweryfikować wersję, pełny tekst i wymagane notices |
| SwiftProtobuf | Lock wskazuje 1.38.1, revision `55d7a1cc5666b85c13464aea1c4b4a90feccb4c8` | Zweryfikować LICENSE/NOTICE checkoutu i dystrybucję notices |
| `.proto` oraz wygenerowane `.pb.swift` | Pochodzenie definicji wymaga ustalenia | Audyt definicji i generatorów |
| Ikona | Własny generator, estetyka inspirowana referencją | Przegląd marki; nie dołączać referencyjnej grafiki Google do produktu |

## Marka

Decyzja użytkownika z 2026-09-16: obecna ikona jest zaakceptowana i pozostaje bez zmian także w wydaniu App Store. Przegląd praw i nazwy nie stanowi polecenia jej przeprojektowania.

**FindHub Android** jest nazwą wybraną przez użytkownika i stosowaną w całym produkcie. Nie planujemy zmiany nazwy ani ikony. Przegląd wydaniowy obejmuje weryfikację dostępności i praw do tej konkretnej nazwy, bez samodzielnego zastępowania jej inną. W opisie można rzetelnie wyjaśnić kompatybilność, zgodnie z prawami do znaków; nie deklarować partnerstwa, certyfikacji ani oficjalnego statusu bez dowodu. Nowa paleta kolorów nie rozstrzyga tych kwestii. [Apple §4.1](https://developer.apple.com/app-store/review/guidelines/#copycats).
