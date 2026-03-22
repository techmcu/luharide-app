# Android release build — Windows file lock (R8 / classes.dex)

If you see:

`The process cannot access the file ... classes.dex because it is being used by another process`

**Do this (order):**

1. Stop **Flutter run** / Chrome / emulator using the project.
2. In `mobile/android`: `gradlew.bat --stop`
3. In `mobile`: `flutter clean`
4. If `build` folder won’t delete: close **Android Studio**, **Cursor** terminals running Gradle, then delete `mobile/build` manually or retry `flutter clean`.
5. Temporarily pause **real-time antivirus** scan on `D:\cur\luharide\mobile` if it keeps locking files.
6. Rebuild:  
   `flutter build apk --target-platform android-arm64`

Your earlier successful build already produced APKs under `build\app\outputs\flutter-apk\` — you can use `app-arm64-v8a-release.apk` from that run if the retry fails.
