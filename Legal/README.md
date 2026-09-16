# Licencje

FindHub Android (wydawca: mintstudio Jakub Koncewicz) jest rozpowszechniana na licencji **GNU GPL v3.0 lub nowszej** (plik `../LICENSE`, podsumowanie w `../NOTICE`), ponieważ zawiera logikę przeniesioną z [GoogleFindMyTools](https://github.com/leonboe1/GoogleFindMyTools) (GPLv3, Leon Böttger). Decyzja D14 z 2026-09-16.

Pełna lista komponentów, autorów i tekstów licencji, dołączana również do aplikacji: [`App/Resources/Licenses/ACKNOWLEDGEMENTS.txt`](../App/Resources/Licenses/ACKNOWLEDGEMENTS.txt).

| Komponent | Licencja | Gdzie w kodzie |
|---|---|---|
| GoogleFindMyTools | GPL-3.0 | `Proto/ProtoDecoders`, porty w `GoogleAuth`, `Nova`, `SpotClient`, `VaultUnlock`, `Crypto`, `ForeignTrackerCryptor`, `LocationDecrypt` |
| firebase-messaging (przez GoogleFindMyTools) | MIT | `FcmRegister.swift`, `McsClient.swift` |
| gpsoauth | MIT | `GoogleAuth.swift` |
| encrypted-content-encoding (http_ece) | MIT | `HttpEce.swift` |
| micro-ecc | BSD-2-Clause | `Sources/uECC` |
| Chromium (definicje checkin/MCS) | BSD-3-Clause | `Proto/firebase`, `Sources/Generated/*.pb.swift` |
| SwiftProtobuf 1.38.1 | Apache-2.0 | Zależność SPM; `SwiftProtobuf-LICENSE.txt` |

Przy każdej dystrybucji udostępnij pełny kod odpowiadający wersji (tag Git) pod adresem z `SOURCE_CODE_URL`. Każdy plik źródłowy ma nagłówek SPDX `GPL-3.0-or-later`; pliki portowane wymieniają źródło, autora i licencję. Zachowuj nagłówki autorów.

Nazwa i logo mintstudio (`docs/assets/mintstudio*.png`) nie są objęte GPL — wszelkie prawa zastrzeżone. Dokument nie jest opinią prawną.
