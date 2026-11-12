# WattWise — Flutter, Firebase AI Logic, SQLite

## Team ownership

| Member | Owned code |
| --- | --- |
| 1 | `lib/app`, `lib/features/dashboard`: navigation, appliance forms, usage estimates, integration |
| 2 | `lib/features/scan_bill`: bill selection, review, breakdown and persistence |
| 3 | `lib/features/mira`, `lib/features/settings`: Firebase AI chat and preferences |

Shared models, repository contracts, storage, translations, components and theme remain under `lib/shared`. Feature branches remain `feature/dashboard`, `feature/scan-bill`, and `feature/mira-settings`.

## Implemented screens

All four tabs and the Add Appliance form use the supplied Figma layouts, green palette, Inter font, rounded cards and original locally bundled SVG icons.

- Dashboard: add/edit/delete appliances; validated wattage, daily hours, days/month and quantity; calculated totals; time-scale and period controls; projected usage/cost chart; editable estimated rate.
- Scan Bill: pick a JPG/PNG up to 8 MB; inspect it; manually enter/review the bill; save the image and bill offline; browse saved bills; view a dynamic charge ring, charge explanations, per-kWh amounts and calculation.
- Mira: contextual Firebase AI conversation, welcome and message bubbles, suggestions, scroll-to-latest, loading state, retry and unavailable states. It reads current appliances and the latest reviewed bill for each request.
- Settings: English/Filipino core interface, light/dark themes, and self-reported Meralco POP enrollment. Preferences are stored locally.

No sample appliances, bills, savings percentages or AI conversations are inserted into user data. Graphs are labeled projections from the current appliance schedule, not meter history. Period controls do not reconstruct historical readings. Month projections use a 30-day allocation; yearly projections use 12 identical configured months. The initial PHP 12/kWh estimate is a sample and can be changed on Dashboard.

## Offline data

`wattwise.db` schema version 2 preserves the existing version 1 appliance table and adds reviewed bills and preferences. Bill images remain on the device in SQLite. Firebase initialization is separate from opening local storage; a Firebase failure does not disable Dashboard, bills or preferences. A storage failure shows a retry screen rather than silently substituting temporary data.

Mira receives appliance data, reviewed bill totals and charge details, language and POP preference. It does not receive the saved bill image. Chat history is session-only.

## Firebase AI and iSee

The existing `lib/firebase_options.dart` is unchanged and still targets `iseeapp-ddf3a`. Mira uses Firebase AI Logic (`firebase_ai`) with the Gemini Developer API backend and the existing default model `gemini-2.5-flash`. Override with `--dart-define=MIRA_MODEL=YOUR_ENABLED_MODEL`.

The copied options still refer to iSee app registrations. Register WattWise's own Android package `com.example.wattwise` and iOS bundle ID in the SAME Firebase project, then regenerate options through FlutterFire before a live release. This work does not change Firebase console settings or App Check enforcement. No service account or Gemini API key was added.

## Remaining integration work

- Automatic OCR/AI bill extraction and PDF import are not implemented. The review screen explicitly describes manual entry.
- A live Firebase AI response has not been tested. Confirm the WattWise registrations, Firebase AI Logic availability, API restrictions and App Check.
- POP preference supplies context only; it does not enroll the user or invent special rates/hours.
- Core labels are translated; some detailed explanations, chart labels, errors and form validation remain English.
- No cloud sync, authentication, meter readings or persistent chat history.
- iOS compilation requires macOS/Xcode and is not verified on this Windows machine.
- The Android/iOS runners present in Downloads are retained with their existing com.example.wattwise identity; launcher icons and release signing still use Flutter defaults.

## Run and verify

Flutter 3.47.5 / Dart 3.13.4 were used. Android and iOS runners are included; the existing platform identifiers in the Downloads copy were preserved.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```

Android build concurrency and memory are limited in `android/gradle.properties` to suit this machine. The first build with Flutter's generated 8 GB heap exhausted native memory; the project now uses a 1.5 GB heap and one Gradle worker.

The tests cover schema migration and persistence, reviewed-bill filtering and fresh Mira context, appliance validation/saving, four-tab rendering, theme/language controls, and narrow screens with larger text. Test previews are written to `build/previews` with isolated test data. No live AI requests are made by the tests.

See `docs/figma_implementation.md` for the design mapping and deliberate data-driven differences.



Verified on 12 November 2026: Flutter analysis passes with no issues; all four tests pass. Android debug APK compilation succeeded after reducing Gradle memory use. Live Firebase AI, OCR and iOS builds remain unverified/pending as described above.
