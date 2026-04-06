# LuhaRide mobile: feature-first + light MVVM

This document tracks moving Flutter code from a flat `screens/` layout into `features/<name>/presentation/...` (and later `data/` where helpful), with small ViewModels extending `ChangeNotifier` instead of piling logic in `State`.

**Non-goals:** REST paths, microservice URLs, and API contracts stay exactly as today. This is a Dart-side structure and presentation-layer refactor only.

## Phases

| Phase | Scope | Status |
|-------|--------|--------|
| **1** | Scaffold: `shared/presentation/base_view_model.dart`, migration doc; pilot: **Landing** under `features/landing` — move screen, fix imports, delete old `screens/landing/landing_screen.dart`. | Done when landing builds clean. |
| **2** | **Auth** flows (`features/auth`): screens moved; `SimpleLoginViewModel` for login loading/obscure toggles; heavier screens unchanged in widget state for safety. | Done |
| **3** | **Trips** + **profile** (`features/trips`, `features/profile`), delete `screens/trips`, `screens/profile`. | Done |
| **4** | **Home** + **notifications** + **admin** (`features/home`, `features/notifications`, `features/admin`); remove `lib/screens/` tree; drop dead `RoleSignupScreen` / `PhoneInputScreen` (never routed). | Done |

## Conventions

- **Feature root:** `lib/features/<feature>/presentation/screens/...` for widgets; `view_models/` when logic is extracted.
- **Shared:** `lib/shared/presentation/` for cross-feature bases (e.g. `BaseViewModel`).
- **Imports:** Prefer package imports if the project adds `package:luharide/...`; until then, consistent relative imports from each file’s depth.

## Step 1 checklist (landing pilot)

- [x] Add this doc and `base_view_model.dart`
- [x] Move `LandingScreen` to `features/landing/presentation/screens/landing_screen.dart`
- [x] Update `main.dart`, landing consumers, `union_admin_home_screen.dart`
- [x] Delete `screens/landing/landing_screen.dart`

## Step 2 checklist (auth)

- [x] Move all auth screens to `features/auth/presentation/screens/` (dead phone/role-signup stubs removed in Step 4 — were never routed)
- [x] Add `SimpleLoginViewModel` + wire `SimpleLoginScreen`
- [x] Update imports: `landing_screen`, trip/search screens (now under `features/trips`)
- [x] Remove `screens/auth/*.dart`

## Step 3 checklist (trips + profile)

- [x] Move all trip screens to `features/trips/presentation/screens/`
- [x] Move all profile screens to `features/profile/presentation/screens/`
- [x] Fix cross-imports (trips ↔ profile, landing, auth signup terms, home shells)
- [x] Remove `screens/trips/` and `screens/profile/` (no duplicate trees)

## Step 4 checklist (home + notifications + admin + cleanup)

- [x] Move `home_screen`, role shells, per-role homes → `features/home/presentation/screens/`
- [x] Move `notifications_screen` → `features/notifications/presentation/screens/`
- [x] Move `kyc_document_viewer_screen` → `features/admin/presentation/screens/`
- [x] Point `main.dart` + auth post-login navigation at `features/home/.../home_screen.dart`
- [x] Delete empty `lib/screens/` (no leftover stubs)
- [x] Remove unused auth entry files: `role_signup_screen.dart`, `phone_input_screen.dart` (zero imports in repo; email/OTP flow is live)
