# Notes for Apple notarization review (paste into App Store Connect → App Review Information → Notes)

Status: ready to paste. Fill in the contact fields in App Store Connect itself. No credentials are needed.

---

FindHub Android is an independent, unofficial iOS client that shows the locations of Google Find Hub trackers (for example Motorola moto tag) that the user has already paired on an Android phone with their own Google account. Location reports are end-to-end encrypted by Google and decrypted on the iPhone. The app has no server of its own.

HOW TO REVIEW WITHOUT AN ACCOUNT
The app needs a Google account with a tracker paired on Android, and unlocking the location keys requires the screen lock of that Android phone. Instead of test credentials, the app offers a full demo mode that anyone can use:

1. Launch the app.
2. On the first screen tap "Try the demo without signing in" (the legal documents can be opened from the links above it).
3. The demo shows four sample trackers in Warsaw, Poland, with sample places, a note and a day of location history. A "DEMO" badge and a "Demo mode" card are always visible.
4. Things to try:
   - Devices tab: tap a tracker in the list, then "Recent location changes" to see the route history (24 h / 48 h / 7 days).
   - "Keep near me and place alerts" on a device; "Add or edit places".
   - Places tab: open "Home" or "Work", add or remove devices.
   - Refresh button: simulates a location update.
   - "Ring nearest": in demo mode it only shows a message; nothing is sent.
   - Avatar/DEMO badge → Settings: notifications (including a test notification), appearance, units, legal information, licences and source code.
5. End the demo from the card or from the account menu ("End demo mode"). All sample data is removed from the device.

In demo mode the app makes no requests to Google and sends no Bluetooth commands. Maps are loaded by MapKit.

PERMISSIONS
- Location (when in use): shows the user on the map, distances to trackers, and helps create places.
- Bluetooth: "Ring nearest" plays the standard DULT non-owner sound on the nearest tracker; optional lost-connection alerts for a tracker the user marks as "keep near me".
- Notifications: local alerts when a tracker leaves a saved place or a Bluetooth connection is lost. Requested when the user saves a place or assigns a device to one.
- Photos: only the photo the user picks for a device (PhotosPicker).
Background modes "bluetooth-central" and "fetch" are used for lost-connection alerts and periodic location refresh; the app does not promise continuous background tracking.

PRIVACY AND LEGAL
Privacy policy: https://github.com/darthkubox/FindHub-Android/blob/main/App/Resources/Legal/privacy-policy.md
Terms of use: https://github.com/darthkubox/FindHub-Android/blob/main/App/Resources/Legal/terms-of-use.md
Source code (GPL-3.0-or-later): https://github.com/darthkubox/FindHub-Android
The app is not affiliated with Google, Motorola or Apple; this is stated on the sign-in screen, in Settings and in the terms of use.
