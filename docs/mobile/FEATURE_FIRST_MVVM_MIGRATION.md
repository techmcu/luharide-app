# LuhaRide mobile: feature-first + light MVVM

This document tracks moving Flutter code from a flat `screens/` layout into `features/<name>/presentation/...` (and later `data/` where helpful), with small ViewModels extending `ChangeNotifier` instead of piling logic in `State`.

**Non-goals:** REST paths, microservice URLs, and API contracts stay exactly as today. This is a Dart-side structure and presentation-layer refactor only.

## Phases

| Phase | Scope | Status |
|-------|--------|--------|
| **1** | Scaffold: `shared/presentation/base_view_model.dart`, migration doc; pilot: **Landing** under `features/landing` — move screen, fix imports, delete old `screens/landing/landing_screen.dart`. | Done when landing builds clean. |
| **2** | **Auth** flows (`features/auth`): screens + ViewModels where `setState` and validation are heavy. | Planned |
| **3** | **Trips** + **profile** (`features/trips`, `features/profile`). | Planned |
| **4** | **Home** shells, optional `data/` facades, remove stale `screens/` paths, full `dart analyze` + smoke test. | Planned |

## Conventions

- **Feature root:** `lib/features/<feature>/presentation/screens/...` for widgets; `view_models/` when logic is extracted.
- **Shared:** `lib/shared/presentation/` for cross-feature bases (e.g. `BaseViewModel`).
- **Imports:** Prefer package imports if the project adds `package:luharide/...`; until then, consistent relative imports from each file’s depth.

## Step 1 checklist (landing pilot)

- [x] Add this doc and `base_view_model.dart`
- [x] Move `LandingScreen` to `features/landing/presentation/screens/landing_screen.dart`
- [x] Update `main.dart`, `profile_screen.dart`, `union_admin_home_screen.dart`
- [x] Delete `screens/landing/landing_screen.dart`
