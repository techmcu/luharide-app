# LuhaRide – Release Build (No Debug)

## Release build = Debug mode off
- `kDebugMode` is **false** in release, so all `debugPrint` and request/response logs **do not run**.
- App is smaller and faster; no console logs in production.

## Android – APK (install directly)

**PowerShell (Windows):**
```powershell
cd D:\cur\luharide\mobile
flutter clean
flutter pub get
flutter build apk --release
```

**Bash / Git Bash:** `cd mobile` then `flutter clean && flutter pub get && flutter build apk --release`

- Output: `build/app/outputs/flutter-apk/app-release.apk`
- Install this APK on device.

## Android – App Bundle (for Play Store)

**PowerShell (Windows):**
```powershell
cd D:\cur\luharide\mobile
flutter clean
flutter pub get
flutter build appbundle --release
```
- Output: `build/app/outputs/bundle/release/app-release.aab`
- Upload this AAB to Google Play Console.

## iOS (if you add later)
```bash
flutter build ios --release
```
Then open Xcode and archive.

## Before first release build
1. Update `version` in `mobile/pubspec.yaml` (e.g. `version: 1.0.0+1`).
2. Ensure `EnvConfig.apiBaseUrl` points to production (VPS), not localhost.

## Push to GitHub
- These changes (rollback + LIMIT + simple search + release-friendly logs) are **safe to push**.
- No breaking change for the app; backend search still returns same shape, with optional `?limit=100` (default 100, max 500) for faster response when rides are many.
