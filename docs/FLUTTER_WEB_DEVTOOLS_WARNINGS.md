# Flutter Web — DevTools / DWDS warnings (harmless)

Hot restart / Chrome par kabhi ye dikhte hain:

```text
Unknown method "ext.flutter.activeDevToolsServerAddress"
Unknown method "ext.flutter.connectedVmServiceUri"
```

Naye Flutter / DWDS versions par aise bhi aa sakta hai:

```text
Failed to set DevTools server address: ext.flutter.activeDevToolsServerAddress: (-32603) Unexpected DWDS error...
Failed to set vm service URI: ext.flutter.connectedVmServiceUri: (-32603) Unexpected DWDS error...
value: Unexpected null value.
Deep links to DevTools will not show in Flutter errors.
```

## Matlab

Ye **app logic / backend / login ki error nahi**.  
IDE ko Chrome ke andar **DevTools deep link** set karne mein fail ho raha hai (`invokeExtension` → null). **App run hoti rehti hai** — sirf DevTools integration thodi tooti.

## Kya karein

- **Ignore** — development mein safe.
- **`flutter upgrade`** + latest **Chrome** + **Flutter extension** update — kabhi-kabhi kam ho jata hai.
- Agar sirf ye dikhe aur UI/API kaam kare → **koi fix zaroori nahi**.

Login/API/VPS se iska **koi link nahi**.
