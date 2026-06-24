# LuhaRide — Documentation Index

All project documentation lives under `docs/`. The repo root stays clean — only
`README.md`, `CLAUDE.md`, and `CODEBASE_MAP.md` (local) remain there.

```
docs/
├── setup/            # Install, run, first-time setup
├── deployment/       # VPS, domain, email/OTP, Railway
├── admin/            # Admin panel access, setup, roles
├── features/         # Feature & flow specs (rides, seats, booking, search)
├── architecture/     # System design, scalability, status, assessments
├── testing/          # Test plans, SOPs, reports
│   └── reports/      # Excel/CSV test reports
├── branding/         # TechMCU branding/style
├── mobile/           # Flutter-specific docs
├── bug-studies/      # Post-mortems of specific bugs
├── archive/          # Historical fix-logs & phase completions (kept for history)
│   ├── fixes/        # One-off "X_FIX / X_COMPLETE" logs
│   └── phases/       # Phase 1 / Phase 2 completion notes
└── _private/         # GITIGNORED — credentials, never committed
```

## Where to look

| I want to… | Folder |
|---|---|
| Run the project locally for the first time | [`setup/`](setup/) |
| Deploy to VPS / configure domain / email-OTP | [`deployment/`](deployment/) |
| Access or set up the admin panel | [`admin/`](admin/) |
| Understand a feature or user flow | [`features/`](features/) |
| Read system design / scalability / honest assessment | [`architecture/`](architecture/) |
| Run or read tests / SOPs | [`testing/`](testing/) |
| Microservices design & migration | the `MICROSERVICES_*` and `ENTERPRISE_*` files in this folder |
| Debug a past bug | [`bug-studies/`](bug-studies/) |

## Key documents

- **Honest engineering review:** [`architecture/ASSESSMENT.md`](architecture/ASSESSMENT.md)
- **Scalability (1 → 1 Cr users):** [`architecture/SCALABILITY_REPORT.md`](architecture/SCALABILITY_REPORT.md)
- **Technical spec:** [`architecture/TECHNICAL_SPEC.md`](architecture/TECHNICAL_SPEC.md)
- **Roadmap:** [`architecture/DEVELOPMENT_ROADMAP.md`](architecture/DEVELOPMENT_ROADMAP.md)
- **Testing SOP:** [`testing/LuhaRide_Testing_SOP.md`](testing/LuhaRide_Testing_SOP.md)

> `archive/` holds old "fix complete" notes — useful for history, not for current work.
> `_private/` is git-ignored and must never be committed.
