# Play Store Assets Guide

## App Icon (DONE)
- File: `app-icon-512x512.png` (in this folder)
- Requirements: 512x512 PNG, 32-bit, no transparency, no rounded corners (Play Store rounds them)
- Source: Resized from `mobile/assets/branding/luharide_launcher_master.png` (1024x1024)

## Feature Graphic (YOU MUST CREATE)
- Size: **1024 x 500 pixels** (PNG or JPG)
- This is the banner shown at the top of your Play Store listing
- **Design suggestions:**
  - Background: Uttarakhand mountain landscape (green/misty hills)
  - LuhaRide logo on the left
  - Tagline on the right: "Your Trusted Ride in Uttarakhand" / "उत्तराखंड में भरोसेमंद सवारी"
  - Brand colors: Dark green (#1B5E20) + Gold/Yellow (#FFC107)
  - Keep text large — most users see this on small screens
- **Tools:** Canva (free), Figma, or Photoshop
- Template search: "Google Play feature graphic template 1024x500"

## Screenshots (YOU MUST CREATE — minimum 2, recommended 4-8)
- Size: 16:9 or 9:16 aspect ratio (phone screenshots work)
- Take these screenshots from the app running on a phone/emulator:

### Recommended screenshots (in order):
1. **Home/Search screen** — shows the main ride search UI
2. **Search results** — list of available rides with driver details
3. **Trip detail** — seat selection, fare, driver info
4. **Booking confirmation** — confirmed booking with driver contact
5. **Driver profile** — ratings, reviews, verified badge
6. **Union dashboard** — (for driver audience) fleet management
7. **Rating/Review** — star rating after trip completion
8. **Notifications** — booking updates, trip reminders

### How to take good screenshots:
1. Run app: `flutter run` on a physical device or emulator
2. Use realistic data (not "Test User" or "Lorem ipsum")
3. Take at clean states (no loading spinners, no error toasts)
4. Screenshot tool: Android built-in (Power + Volume Down) or `adb exec-out screencap -p > screenshot.png`
5. Optional: Add frames using https://mockuphone.com or Canva device mockup templates

## AAB Build (App Bundle — required by Play Store)
```bash
cd mobile
flutter build appbundle --release
```
Output: `mobile/build/app/outputs/bundle/release/app-release.aab`

**Important:** APK is NOT accepted on Play Store. Only AAB (Android App Bundle).
