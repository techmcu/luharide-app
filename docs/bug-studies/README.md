# 🐛 Bug Studies — LuhaRide

Yeh folder real bugs ki **case studies** rakhta hai — jo LuhaRide me aaye, kaise pakde gaye, aur kaise permanently fix hue.

**Maksad:** Future me aisa issue aaye toh yahan se seekh ke khud fix kar paao. Har case study me — real story, technical root cause, diagrams, aur fix.

## Index

| #   | Title | Type | One-line |
|-----|-------|------|----------|
| 001 | [Fellow Travelers khaali dikh raha tha](./001-fellow-travelers-dynamic-type-crash.md) | Flutter / Dart runtime crash | Backend sahi data bhej raha tha, par app ek `dynamic` type error pe crash karke poora response gira deti thi |
| 002 | [Union "Create Ride" ke 5 problems + idempotency](./002-union-ride-creation-and-idempotency.md) | Backend logic + system design | "3 se zyada nahi" error, poster icon gayab, ride kabhi banti kabhi nahi — 5 alag root cause; fix + duplicate-proof (idempotency / defense-in-depth) |

## Naya case study kaise add karein

1. Naya file banao: `NNN-short-title.md` (NNN = next number)
2. Template follow karo (story → diagram → root cause → fix → lesson)
3. Upar table me ek row add kar do

## Har case study me kya hona chahiye

- **Real-life story** — symptom kya tha, user ko kya dikh raha tha
- **Debugging journey** — kaise dhoondha (galat raaste bhi, taaki seekh mile)
- **Diagram** — data flow aur exactly kahan toota
- **Root cause** — technically kya galat tha
- **Fix** — before/after code, aur kyun permanent hai
- **Lesson** — future me kaise turant pakdein
