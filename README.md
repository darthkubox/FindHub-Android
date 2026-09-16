<p align="center">
  <img src="docs/assets/findhub-android-icon.png" width="128" height="128" alt="FindHub Android icon">
</p>

<h1 align="center">FindHub Android</h1>

<p align="center">
  Unofficial native iOS client for Google Find Hub trackers — map, history, places and Bluetooth ringing, fully on-device.<br>
  <b>Not affiliated with Google.</b> Licensed under GPLv3.
</p>

---

> [!IMPORTANT]
> **FindHub Android is an independent, unofficial project.** It is not affiliated with, endorsed or supported by Google LLC, Motorola or Apple Inc. Google does not offer a public Find Hub API; this app talks to Google services the way the reverse-engineered [GoogleFindMyTools](https://github.com/leonboe1/GoogleFindMyTools) project does. Google may change or block this at any time, and use of an unofficial client may conflict with Google's terms. Use it at your own risk.

## What it does

FindHub Android lets iPhone users see the Find Hub tags (for example Motorola moto tag) that were **already paired on an Android phone** with their Google account.

- **Map** of your tags and your own position, with clustering, report time, accuracy and distance.
- **Locate** a tag through the Find Hub network; reports are decrypted **on the iPhone** (AES-GCM / SECP160r1 + AES-EAX).
- **7-day local history** with honest gaps (no fabricated route points).
- **Places**: home, work and other zones, with local alerts when fresh reports confirm a tag left a zone.
- **Ring**: over the network for a specific tag, or the nearest tag via Bluetooth using the standard DULT non-owner sound.
- **Bluetooth separation alerts** after a confirmed connection to a tag.
- Custom names, icons, photos and notes, multiple Google accounts, light and dark mode.
- **Delete this account's data from the phone** in Settings.

### Limitations

- No pairing of new tags (pair on Android first), no UWB precision finding, no battery level.
- Reports can be delayed; background work and alerts depend on iOS and are not guaranteed.
- iOS 17 or later, iPhone only.

## Privacy

There is **no server** operated by this project. Tokens and encryption keys stay in the iPhone Keychain. History, places and notes are stored locally and excluded from device backups; custom device names, icons and photos are stored in regular app storage. The app contacts Google (sign-in, device list, location reports, ring requests) and Apple (MapKit) only to provide its features. Nothing is sent to mintstudio.

## Legal

- **Privacy policy** (Polish, binding): [App/Resources/Legal/polityka-prywatnosci.md](App/Resources/Legal/polityka-prywatnosci.md)
- **Terms of use** (Polish, binding): [App/Resources/Legal/warunki-korzystania.md](App/Resources/Legal/warunki-korzystania.md)
- Both documents ship inside the app (**Ustawienia → Informacje prawne**) and must be accepted before signing in. In short: the app is free GPLv3 software provided without warranty; use it only with your own Google account and devices, never to track other people; mintstudio receives no personal data.
- Data-flow analysis (Polish): [docs/04-PRYWATNOSC-I-BEZPIECZENSTWO.md](docs/04-PRYWATNOSC-I-BEZPIECZENSTWO.md)

## Install

- **AltStore PAL (EU):** planned. The app is not yet notarized; this section will link the AltStore source once it is published.
- **Not on the App Store:** Apple requires permission from the third-party service (guideline 5.2.2), which Google does not provide for Find Hub.

### Build from source

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cp App/Config/Local.xcconfig.example App/Config/Local.xcconfig   # set your DEVELOPMENT_TEAM
xcodegen generate --spec App/project.yml
open "App/FindHub Android.xcodeproj"
bash Scripts/check_local.sh          # offline regression tests, no account or network
```

## Credits and licenses

FindHub Android stands on the work of these projects. Full license texts are in [`App/Resources/Licenses/ACKNOWLEDGEMENTS.txt`](App/Resources/Licenses/ACKNOWLEDGEMENTS.txt) and are shown in the app under **Ustawienia → Licencje i kod źródłowy** (Settings → Licenses and source code).

| Project | Authors | License | Used for |
|---|---|---|---|
| [GoogleFindMyTools](https://github.com/leonboe1/GoogleFindMyTools) | Leon Böttger (SEEMOO, TU Darmstadt) | GPL-3.0 | Protocol definitions and the ported auth, Nova, Spot, key and report-decryption logic |
| [firebase-messaging](https://github.com/sdb9696/firebase-messaging) | Matthieu Lemoine, Steven Beth | MIT | FCM registration and MCS push connection (ported) |
| [gpsoauth](https://github.com/simon-weber/gpsoauth) | Simon Weber | MIT | Google account token exchange (ported) |
| [encrypted-content-encoding](https://github.com/martinthomson/encrypted-content-encoding) | Martin Thomson | MIT | Web Push `aesgcm` decryption (ported) |
| [micro-ecc](https://github.com/kmackay/micro-ecc) | Kenneth MacKay | BSD-2-Clause | SECP160r1 elliptic-curve operations (bundled) |
| [Chromium](https://chromium.googlesource.com/chromium/src) | The Chromium Authors | BSD-3-Clause | Checkin and MCS protobuf definitions |
| [SwiftProtobuf](https://github.com/apple/swift-protobuf) | Apple Inc. and contributors | Apache-2.0 | Protobuf runtime (Swift Package) |

References: [Find Hub Network Accessory Specification](https://developers.google.com/nearby/fast-pair/specifications/extensions/fmdn), [IETF DULT](https://datatracker.ietf.org/wg/dult/about/), [Material Design 3](https://m3.material.io).

If you use this work academically, please also cite GoogleFindMyTools as described in its `CITATION.cff`.

### License

Copyright © 2026 mintstudio Jakub Koncewicz.

This program is free software: you can redistribute it and/or modify it under the terms of the **GNU General Public License v3.0** or (at your option) any later version. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

**Trademarks.** Google, Find Hub and Android are trademarks of Google LLC. Motorola and moto tag are trademarks of Motorola Trademark Holdings, LLC. Apple and iPhone are trademarks of Apple Inc. They are used here only to describe compatibility. The mintstudio name and logo are not covered by the GPL; all rights reserved.

## Po polsku

FindHub Android to nieoficjalna, otwartoźródłowa aplikacja na iPhone’a do przeglądania tagów Google Find Hub sparowanych wcześniej na Androidzie. Wszystko działa na telefonie, bez serwera. Aplikacja nie jest powiązana z Google. Dokumentacja projektu i planu wydania jest po polsku: [docs/00-PRZEGLAD.md](docs/00-PRZEGLAD.md).

## Contact

Issues and pull requests are welcome. Contact: [kontakt@mintstudio.pl](mailto:kontakt@mintstudio.pl).

<p align="center">
  <a href="mailto:kontakt@mintstudio.pl">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="docs/assets/mintstudio-white.png">
      <img src="docs/assets/mintstudio.png" width="200" alt="mintstudio">
    </picture>
  </a>
</p>
