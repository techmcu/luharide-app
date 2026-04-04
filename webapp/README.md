# LuhaRide — static web build (Flutter)

Regenerate after UI or `mobile/` changes:

```bash
cd mobile && flutter build web --release
```

Then replace this folder with `mobile/build/web/` contents (or re-run your deploy script).

Serve locally: `npx serve .` from this directory (or any static file host).
