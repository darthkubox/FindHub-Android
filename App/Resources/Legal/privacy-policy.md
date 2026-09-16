# FindHub Android Privacy Policy

Version 1, effective 17 September 2026. This is the English version; a Polish version is also available. If the versions differ, the Polish version prevails to the extent permitted by law.

## 1. Who is responsible for the app

FindHub Android is published by **mintstudio Jakub Koncewicz** (“mintstudio”, “we”). Privacy contact: **kontakt@mintstudio.pl**.

FindHub Android is an independent, unofficial app. It is not affiliated with Google LLC, Motorola or Apple Inc.

## 2. The essentials

- **mintstudio does not receive your data.** We have no server, user accounts, analytics, advertising or tracking tools. The app sends nothing to us.
- Data is processed **on your iPhone**. Tokens and encryption keys are kept in the iPhone Keychain.
- To work, the app connects to **Google** (your account and the Find Hub service) and to **Apple** services (maps and address search). The data described in section 4 is sent to those companies.
- You can delete all data stored by the app yourself (section 6).

## 3. What data the app processes on your phone

- **Google account:** email address, profile photo, access tokens, a device identifier issued by Google and push notification credentials. Stored in the Keychain, on this iPhone only, not included in iCloud backups.
- **Location encryption keys (E2EE):** obtained after you unlock them on Google’s page; stored in the Keychain. Used only to decrypt location reports on the phone.
- **Devices and locations:** the list of your Find Hub devices, their identifiers and decrypted positions with time and accuracy.
- **History:** positions from the last 7 days, stored locally and excluded from backups.
- **Places and notes:** areas you save (e.g. home), device assignments, notes and alert settings. Stored locally and excluded from backups.
- **Personalisation:** custom device names, icons and photos, and app settings. These may be included in your iPhone backup together with the app’s data.
- **iPhone location:** used while the app is open to show you on the map, calculate distances and create places. We do not keep a history of your position.
- **Bluetooth:** finding nearby trackers, ringing and lost-connection alerts. The system identifier of a connected tracker is remembered.
- **Photos:** only the photo you choose for a device; a downscaled copy is stored. The app has no access to the rest of your library.
- **Notifications:** local alerts created on the phone; they may contain device and place names.

## 4. Who receives data

**Google LLC / Google Ireland Limited.** The app acts as a client of your Google account, so it sends to Google:

- the sign-in details you enter on Google’s page (sign-in takes place on Google’s page; the app does not store your password);
- account tokens, the device identifier and push notification registration data;
- requests for the device list, locations and ringing, including device identifiers;
- your IP address and technical connection information.

Google returns the device list, encrypted location reports, the owner key in encrypted form, and profile and product images. Google processes this data under its own policy: https://policies.google.com/privacy

**Apple Inc. / Apple Distribution International Ltd.** Maps (MapKit) download map tiles for the area you view. In the place editor, address and place-name lookups send the text you type or the coordinates to Apple. Location Services, Bluetooth and notifications are handled by iOS. Apple’s policy: https://www.apple.com/legal/privacy/

**Maps apps at your request.** When you choose Google Maps or Apple Maps in a device’s details, the device’s coordinates are passed to that app or website.

We do not sell data or share it with anyone else.

## 5. Purposes and legal basis

Data is processed solely so that the app works as you instruct: showing your devices, their history, places and alerts. mintstudio has no access to this data and does not decide how it is used beyond the app running on your phone. Google and Apple are responsible for processing in their services.

Access to location, Bluetooth, notifications and photos requires your permission in iOS. You can withdraw it at any time in the iPhone Settings; some features will then stop working.

## 6. Retention and deletion

- History older than 7 days is deleted when the app processes data (for example, at launch).
- Places, notes and personalisation are kept until you delete them.
- **Sign out** removes the account’s tokens and keys from the Keychain but keeps history, places and notes in case you sign in again.
- **Settings → Delete this account’s data from the phone** permanently removes the account’s history, places, notes, device names, icons and photos, alerts, tokens and keys.
- Deleting the app removes its files. iOS may keep Keychain items after the app is deleted; use the data deletion option before removing the app.
- The app does not delete your Google account or data stored by Google. You can review and revoke a device’s access to your account at https://myaccount.google.com/security

## 7. Your rights

Data stored in the app is under your control on your phone: you can view, change and delete it. Because mintstudio does not receive it, we cannot provide, correct or delete it for you. Exercise your rights regarding data held by Google with Google. If you believe your data is processed unlawfully, you may lodge a complaint with a data protection authority, in Poland the President of the Personal Data Protection Office (https://uodo.gov.pl), or the authority in your country of residence.

## 8. Security

Connections to Google and Apple are encrypted. Tokens and keys are kept in a Keychain available only on this device after first unlock. Location reports are decrypted on the phone. The app’s system logs do not reveal device names, coordinates or tokens. The app’s source code is public: https://github.com/darthkubox/FindHub-Android

## 9. Children

The app requires a Google account and is not intended for people who cannot use a Google account on their own in their country.

## 10. Changes to this policy

Changes are announced in a new version of the app and in the project repository. The version number and date are shown at the top of this document.

## 11. Contact

mintstudio Jakub Koncewicz — kontakt@mintstudio.pl
