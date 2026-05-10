# Privacy Policy Audit — Fixes Required

URL: https://luharide.cloud/privacy/
Audited: 2026-05-10

---

## CRITICAL — Must Fix Before Play Store Submission

### 1. Real-Time Location Tracking Not Disclosed
**Issue:** The policy says location is used "when you search for rides, create trips, or use map features." But the app tracks driver GPS location **continuously during active trips** via Socket.IO and shares it with passengers in real-time. This is a fundamentally different use case (continuous background tracking vs. on-demand).

**Fix — add to "Location Services" section:**
> **Real-Time Tracking:** When a driver starts a trip, LuhaRide collects and transmits the driver's GPS location continuously to provide real-time trip tracking for passengers. This location data is shared only with passengers who have a confirmed booking on that specific trip. Location tracking stops automatically when the trip is completed or cancelled. Drivers can see that tracking is active via the app interface.

**Why critical:** Google Play requires explicit disclosure of background/continuous location access. Failure = rejection or suspension.

### 2. Password Reference — App Uses OTP
**Issue:** The policy says "You will be asked to confirm with your password" for account deletion, and mentions "Password hashing (bcrypt)." But LuhaRide uses OTP-based authentication, not passwords.

**Fix:**
- Change "confirm with your password" → "confirm with an OTP sent to your registered phone number"
- Change "Password hashing (bcrypt) for account security" → "OTP-based authentication for account security"

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
| 1 | Real-time location tracking not disclosed | CRITICAL | Can cause rejection |
| 2 | Password references (app uses OTP) | CRITICAL | Inconsistency = trust issue |
| 3 | No Grievance Officer named | MEDIUM | Indian law requirement |
| 4 | DPDP Act 2023 references | MEDIUM | Legal compliance |
| 5 | No governing law clause | LOW | Best practice |
