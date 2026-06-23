# Privacy Policy Audit — Fixes Required

URL: https://luharide.cloud/privacy/
Audited: 2026-05-10

---

## CRITICAL — Must Fix Before Play Store Submission

### 1. Real-Time Location Tracking Not Disclosed
**Issue:** The policy says location is used "when you search for rides, create trips, or use map features." But the app tracks driver GPS location **continuously during active trips** via Socket.IO and shares it with passengers in real-time. This is a fundamentally different use case (continuous background tracking vs. on-demand).

**Fix — add to "Location Services" section:**
> **Real-Time Tracking:** When a driver starts a trip, LuhaRide collects and transmits the driver's GPS location continuously to provide real-time trip tracking for passengers. This location data is shared only with passengers who have a confirmed booking on that specific trip. Location tracking stops automatically when the trip is completed or cancelled. Drivers can see that tracking is active via the app interface.
>
> **On-demand current location (Passengers & Drivers):** When you tap "Use my current location", LuhaRide accesses your device location (approximate and/or precise) **in the foreground only** to auto-fill your pickup point and show nearby rides. This is optional — you can deny or revoke the permission anytime and continue using the app by typing locations manually. We do not track this location in the background.

**Why critical:** Google Play requires explicit disclosure of any location access (foreground or background). Failure = rejection or suspension.

### 2. Auth description — keep it accurate to the REAL app
**Reality (verified in code):** Login = **email + password** OR **Google Sign-In**. Signup = **email + OTP verification + password**. Forgot-password = **email OTP** reset. Account deletion = **confirm with password**. There is **NO phone-number login/OTP**.

**Fix (make the policy match this — do NOT claim "OTP-only / no passwords"):**
- Keep "confirm with your password" for account deletion (this is correct).
- Keep "Password hashing (bcrypt)" — passwords ARE used and hashed.
- Where the policy mentions OTP, clarify it is **email OTP for signup & password reset** (not phone OTP).

---

## MEDIUM — Should Fix

### 3. No Grievance Officer Named
**Issue:** Indian IT Act 2000 (Information Technology (Intermediary Guidelines) Rules, 2021) requires platforms to appoint and name a Grievance Officer with contact details and response timeline (max 72 hours acknowledgment, 30 days resolution).

**Fix — add to "Contact Us" section:**
> **Grievance Officer (as per IT Act 2000):**
> Name: [Your Name]
> Email: supportluharide@gmail.com
> Response time: We acknowledge grievances within 72 hours and aim to resolve within 30 days.

### 4. DPDP Act 2023 Compliance
**Issue:** India's Digital Personal Data Protection Act 2023 requires:
- Clear mention of "Data Fiduciary" (that's you/TECHMCU)
- Mention of right to nominate (users can nominate someone to exercise rights on their behalf)
- Explicit consent mechanism description

**Fix — add a small section:**
> **DPDP Act 2023:** TECHMCU acts as the Data Fiduciary for personal data collected through LuhaRide. You have the right to nominate another person to exercise your data rights on your behalf, as provided under the Digital Personal Data Protection Act, 2023.

---

## LOW — Nice to Have

### 5. No Governing Law Clause
**Fix — add before "Contact Us":**
> **Governing Law:** This Privacy Policy is governed by the laws of India. Any disputes shall be subject to the exclusive jurisdiction of courts in Dehradun, Uttarakhand.

### 6. No Effective Date vs Last Updated Distinction
Minor — current "Last updated: 18 April 2026" is acceptable for Play Store.

---

## Summary

| # | Issue | Severity | Play Store Impact |
|---|-------|----------|-------------------|
| 1 | Location not disclosed (real-time driver tracking + on-demand "use my current location" / Ola) | CRITICAL | Can cause rejection |
| 2 | Auth description must match reality (email+password + email-OTP signup + Google; NO phone-OTP) | CRITICAL | Inconsistency = trust issue |
| 3 | No Grievance Officer named | MEDIUM | Indian law requirement |
| 4 | DPDP Act 2023 references | MEDIUM | Legal compliance |
| 5 | No governing law clause | LOW | Best practice |
