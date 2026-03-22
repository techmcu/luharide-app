# Flutter Web — DevTools “Unknown method” warnings

Hot restart / Chrome par kabhi ye dikhte hain:

```text
Unknown method "ext.flutter.activeDevToolsServerAddress"
Unknown method "ext.flutter.connectedVmServiceUri"
```

Ye **app logic ki error nahi** — Flutter tooling / IDE aur embedded browser ke beech version mismatch. App chal sakti hai.

**Kya karein:** ignore, ya `flutter upgrade` / IDE update. Login/API se iska koi link nahi.
