# Frontend

This is the Flutter client for the HKU Library Booking System.

Use the root [README.md](../README.md) for full-stack setup. This file only covers frontend-specific run and config details.

## Quick Start

From `frontend/`:

```bash
flutter pub get
cp dart_defines.json.example dart_defines.json
flutter run --dart-define-from-file=dart_defines.json
```

## Backend URL Configuration

The app reads `BASE_URL` from `dart_defines.json`.

Example:

```json
{
  "BASE_URL": "http://192.168.x.x:8000"
}
```

Default behavior in [`lib/core/config/backend_config.dart`](./lib/core/config/backend_config.dart):

- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://localhost:8000`
- web: `http://localhost:8000`

If you are running on a physical phone, set `BASE_URL` to your Mac's LAN IP, not `localhost`.

## Xcode Note

When you run the iOS app directly from Xcode, `dart_defines.json` is not picked up automatically.

Create `frontend/ios/Flutter/Local.xcconfig` and set a `DART_DEFINES` value there instead.

Example:

```bash
printf 'BASE_URL=http://192.168.x.x:8000' | base64
```

Then place the encoded value in:

```xcconfig
DART_DEFINES=$(inherited),<base64 encoded BASE_URL=...>
```

`Local.xcconfig` should stay machine-local.

## Permissions And Platform Notes

- Android already allows cleartext local dev traffic in [`android/app/src/main/AndroidManifest.xml`](./android/app/src/main/AndroidManifest.xml).
- iOS allows local-network and development HTTP access in [`ios/Runner/Info.plist`](./ios/Runner/Info.plist).
- The app requests location permission to support nearby library features.
- The app uses local notifications for booking reminders, so notification permission may be requested during use.

## Main App Structure

- [`lib/app`](./lib/app): app bootstrap and root shell
- [`lib/core`](./lib/core): shared config, auth, models, network, and UI primitives
- [`lib/features`](./lib/features): feature modules such as auth, home, library, reservations, reports, and AI agent
- [`lib/providers`](./lib/providers): app-wide state and session coordination
- [`lib/services`](./lib/services): platform integrations such as notifications
- [`lib/theme`](./lib/theme): theme tokens and styling

## Common Local Issues

- If the app loads but API calls fail, check `BASE_URL` first.
- If iOS works in `flutter run` but not in Xcode, check `Local.xcconfig`.
- If booking reminders do not appear, check OS notification permission.
- If nearby library results look wrong, check location permission or fallbacks.
