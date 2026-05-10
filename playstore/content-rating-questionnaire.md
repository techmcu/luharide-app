# Google Play Content Rating Questionnaire — LuhaRide

Use these answers when filling the IARC content rating questionnaire in Google Play Console.

## Violence
- Does the app contain violence? **No**
- Does the app depict violent acts against characters? **No**

## Sexual Content
- Does the app contain sexual content? **No**
- Does the app contain nudity? **No**

## Language
- Does the app contain profanity, crude humor, or strong language? **No**

## Controlled Substances
- Does the app reference or depict use of drugs, alcohol, or tobacco? **No**

## Gambling
- Does the app contain simulated gambling? **No**
- Does the app facilitate real-money gambling? **No**

## User Interaction
- Can users communicate or exchange content? **Yes**
  - Users can rate and review drivers
  - Users can file complaints with text
  - Users can share contact info (phone/WhatsApp) after booking confirmation
- Does the app share user's location with other users? **Yes**
  - Real-time driver location shared during active trips
- Can users purchase digital goods? **No**

## Personal Information
- Does the app collect personal data? **Yes**
  - Phone number (for OTP login)
  - Name, email, profile photo
  - Government IDs (Aadhaar, DL, RC) for driver/union verification
  - Device location
- Does the app share personal data with third parties? **Yes** (service providers only — SMS, email, hosting)

## Ads
- Does the app contain ads? **No**

## Miscellaneous
- Is the app a government app? **No**
- Is the app a news app? **No**
- Is the app an education app? **No**

---

## Expected Rating: **Everyone** (possibly **Everyone 10+** due to user interaction features)

## Data Safety Section Answers

Fill these in Play Console under "Data safety":

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Phone number | Yes | Yes (with other users after booking) | Account, App functionality |
| Name | Yes | Yes (with other users) | Account, App functionality |
| Email | Yes | No | Account |
| Location (precise) | Yes | Yes (driver location with passengers) | App functionality |
| Photos | Yes (profile, documents) | No | Account, Verification |
| Government ID (Aadhaar, DL) | Yes | No | Identity verification |
| App interactions | Yes | No | Analytics |
| Crash logs | Yes | No | App diagnostics |
| Device ID | Yes | No | Analytics, Security |

**Encryption in transit:** Yes (HTTPS/TLS)
**Deletion mechanism:** Yes (in-app account deletion)
