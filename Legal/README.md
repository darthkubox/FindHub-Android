# Licences

**English** · [Polski](README.pl.md)

Tagpin (publisher: mintstudio Jakub Koncewicz) is distributed under the **GNU GPL v3.0 or later** (file `../LICENSE`, summary in `../NOTICE`), because it contains logic ported from [GoogleFindMyTools](https://github.com/leonboe1/GoogleFindMyTools) (GPLv3, Leon Böttger).

The full list of components, authors and licence texts, also shipped inside the app: [`ACKNOWLEDGEMENTS-en.txt`](../App/Resources/Licenses/ACKNOWLEDGEMENTS-en.txt) (Polish: [`ACKNOWLEDGEMENTS-pl.txt`](../App/Resources/Licenses/ACKNOWLEDGEMENTS-pl.txt)).

| Component | Licence | Where in the code |
|---|---|---|
| [GoogleFindMyTools](https://github.com/leonboe1/GoogleFindMyTools) | GPL-3.0 | `Proto/ProtoDecoders`, ports in `GoogleAuth`, `Nova`, `SpotClient`, `VaultUnlock`, `Crypto`, `ForeignTrackerCryptor`, `LocationDecrypt` |
| [firebase-messaging](https://github.com/sdb9696/firebase-messaging) (via GoogleFindMyTools) | MIT | `FcmRegister.swift`, `McsClient.swift` |
| [gpsoauth](https://github.com/simon-weber/gpsoauth) | MIT | `GoogleAuth.swift` |
| [encrypted-content-encoding (http_ece)](https://github.com/web-push-libs/encrypted-content-encoding) | MIT | `HttpEce.swift` |
| [micro-ecc](https://github.com/kmackay/micro-ecc) | BSD-2-Clause | `Sources/uECC` |
| [Chromium](https://chromium.googlesource.com/chromium/src/+/main/google_apis/gcm/protocol/) (checkin/MCS definitions) | BSD-3-Clause | `Proto/firebase`, `Sources/Generated/*.pb.swift` |
| [SwiftProtobuf 1.38.1](https://github.com/apple/swift-protobuf) | Apache-2.0 | SPM dependency; `SwiftProtobuf-LICENSE.txt` |

Every distribution must make the complete corresponding source available (Git tag) at the `SOURCE_CODE_URL` address. Each source file carries an SPDX `GPL-3.0-or-later` header; ported files name their origin, author and licence. Keep author headers intact.

The mintstudio name and logo (`docs/assets/mintstudio*.png`) are not covered by the GPL — all rights reserved. This document is not legal advice.
