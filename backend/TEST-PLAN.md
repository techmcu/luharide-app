# LuhaRide Backend — Automated Test Plan

Mapped to SOP v1.0 (2026-06-09, 250 test cases, Parts A–F).

## How tests work

```
You (local) → git push → GitHub CI runs `npm test` → Pass → VPS deploy
                                                    → Fail → Deploy blocked
```

- Tests run ONLY in CI (GitHub Actions) — never on VPS, never in APK
- Test files live next to source: `someFile.js` → `someFile.test.js`
- All tests are mock-based (no real DB/Redis needed)
- APK size: ZERO impact (these are backend-only)
- VPS size: ~50-100KB total (negligible)

---

## Existing tests (22 files, 208 tests) ✅

| # | File | What it covers |
|---|------|----------------|
| 1 | `src/middleware/errorHandler.test.js` | Error conversion, DB errors, JWT errors, 5xx hiding |
| 2 | `src/middleware/metricsCollector.test.js` | Request metrics recording |
| 3 | `src/middleware/otpRateLimitKeys.test.js` | OTP rate limit key generation |
| 4 | `src/middleware/parseLimitEnv.test.js` | Env var parsing for rate limits |
| 5 | `src/middleware/redisCache.test.js` | Redis cache middleware |
| 6 | `src/middleware/apiVersionRewrite.test.js` | API version URL rewriting |
| 7 | `src/socket/socketRateLimit.test.js` | Socket connection rate limiting |
| 8 | `src/utils/sanitizeKycUploadUrl.test.js` | KYC URL sanitization, path traversal |
| 9 | `src/utils/resolveVerifiedUploadPath.test.js` | Upload path resolution |
| 10 | `src/utils/telegramAlert.test.js` | Telegram alert formatting |
| 11 | `src/controllers/kycDocumentsCollect.test.js` | KYC document collection |
| 12 | `src/controllers/tripSearchColumns.test.js` | Trip search column mapping |
| 13 | `src/controllers/tripController.test.js` | Trip CRUD basics |
| 14 | `src/controllers/bookingController.test.js` | Booking CRUD basics |
| 15 | `src/controllers/union/unionController.test.js` | Union basics |
| 16 | `src/jobs/kycQueue.test.js` | KYC PDF queue processing |
| 17 | `src/constants/pagination.test.js` | Pagination defaults |
| 18 | `src/config/retentionConfig.test.js` | Retention policy config |
| 19 | `gateway/circuitBreaker.test.js` | Circuit breaker logic |
| 20 | `migrations/migrationFiles.test.js` | Migration file integrity |
| 21 | `tests/integration/auth.flow.test.js` | Auth token flow |
| 22 | `tests/smoke/simple_auth_ping.test.js` | Health endpoint smoke |

---

## New tests to write — in priority order

### Phase 1: Business Logic Hardening (SOP Part F) — MOST CRITICAL

These test the edge cases that can lose money or break trust.

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 1 | EXTEND | `src/controllers/tripController.test.js` | BL-001→005 | 2-hour advance, same from-to block, overlapping rides, fare min/max |
| 2 | EXTEND | `src/controllers/bookingController.test.js` | BL-006→010 | Departed ride block, duplicate booking, cancel-block, auto-confirm 2min, normal 30min |
| 3 | NEW | `src/controllers/bookingController.cancel.test.js` | BL-011→016 | 1-hour cutoff, 5-min grace, grace expired, repeat offender 8 cancels, block expiry, driver rating on cancel |
| 4 | NEW | `src/controllers/tripController.cancel.test.js` | BL-017→023 | 5-hour cutoff, 5-min grace, no-passengers always cancel, repeat offender 5 cancels, passenger rating on cancel, cancel in-progress blocked |
| 5 | NEW | `src/controllers/bookingController.respond.test.js` | BL-024→026 | Accept after departure blocked, reject after departure, reject notification |
| 6 | NEW | `src/controllers/tripController.lifecycle.test.js` | BL-027→028 | Manual start blocked, complete before departure blocked |
| 7 | NEW | `src/controllers/reviewController.test.js` | BL-029→033 | Rate after cancel (both sides), canceller can't rate, auto-cancel no rating |
| 8 | NEW | `src/controllers/notificationController.test.js` | BL-034→038 | No double-ding, FCM when offline, read retention 48h, unread 7d, duplicate broadcast block |

### Phase 2: Auth & Login (SOP Part A1)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 9 | NEW | `src/controllers/simpleAuthController.test.js` | P-001→002, P-006→007, P-010→016, P-018 | Email signup, login, forgot password, change password, duplicate email, empty fields, wrong password, OTP wrong code, session expired, unregistered email |
| 10 | EXTEND | `tests/integration/auth.flow.test.js` | P-008, P-009, P-015, P-016 | Logout invalidation, delete account, session persistence, token expiry |

### Phase 3: Search & Booking Flow (SOP Part A2-A3)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 11 | EXTEND | `src/controllers/tripController.test.js` | P-019→021, P-025, P-027 | Search rides, no results, location suggestions, date filter, trip details |
| 12 | EXTEND | `src/controllers/bookingController.test.js` | P-028→033 | Seat layout, select seats, book seat, duplicate block, cannot book own trip |
| 13 | NEW | `src/controllers/bookingController.myrides.test.js` | P-036→041 | View bookings, status colors, cancel pending, cancel confirmed, cancel too late, cancellation reason |

### Phase 4: Reviews & Profile (SOP Part A4-A5)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 14 | EXTEND | `src/controllers/reviewController.test.js` | P-042→046 | Rate driver 1-5, review comment, view driver reviews, view my ratings, rate reminder |
| 15 | NEW | `src/controllers/profileController.test.js` | P-047→052 | Edit name, phone, email, profile photo, WhatsApp number, bio |

### Phase 5: Notifications (SOP Part A6)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 16 | EXTEND | `src/controllers/notificationController.test.js` | P-053→058 | In-app notifications, mark read, mark all read, unread badge, union ride FCM |

### Phase 6: Driver Features (SOP Part B)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 17 | NEW | `src/controllers/driverVerificationController.test.js` | D-001→014 | Submit aadhaar/DL, select vehicle, custom vehicle, reg number, submit full KYC, missing docs, view status, rejection reason, re-verify, watermark, union exclusivity, file size |
| 18 | EXTEND | `src/controllers/tripController.test.js` | D-015→021 | Create trip, location autocomplete, set fare, set seats, add stops, luggage, approval mode |
| 19 | EXTEND | `src/controllers/tripController.test.js` | D-022→028B | View my trips, auto-start, auto-complete, cancel trip, cancel too late, delete trip, delete has bookings, delete after 1 hour |
| 20 | EXTEND | `src/controllers/bookingController.test.js` | D-029→033 | View bookings, accept, reject, view passenger rating, rate passenger |

### Phase 7: Union Features (SOP Part C)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 21 | NEW | `src/controllers/union/unionRegistrationController.test.js` | U-001→008 | Register union, missing docs, duplicate phone, already has union, check status, optional docs, share notes, auto PDF merge |
| 22 | EXTEND | `src/controllers/union/unionController.test.js` | U-009→011 | Dashboard stats, pending KYC badge, contact analytics |
| 23 | NEW | `src/controllers/union/unionDriverController.test.js` | U-012→016 | Add driver, missing fields, view all, remove driver, search |
| 24 | NEW | `src/controllers/union/unionRouteController.test.js` | U-017→019 | Add route, view routes, delete route |
| 25 | NEW | `src/controllers/union/unionScheduleController.test.js` | U-020→029 | Bulk create, no drivers, daily limit 3, max 50, FCM first ride, no FCM repeat, rotating messages, view current/recent, cancel |
| 26 | NEW | `src/controllers/union/unionPosterController.test.js` | U-030→036 | Poster header, custom text, layout, theme, download single/combined, share |
| 27 | NEW | `src/controllers/union/unionDocumentController.test.js` | U-037→040 | Re-upload with/without permission, document status, deadline |
| 28 | NEW | `src/controllers/kycAdminController.test.js` | U-041→048 | Approve/reject driver, approve/reject union, grant re-verify, driver/union directory, stream document |

### Phase 8: Platform Admin (SOP Part D)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 29 | NEW | `src/controllers/platformAdminController.test.js` | A-001→019 | Dashboard stats, trip stats, today's trips, new users, active drivers, pending KYC, user management, search, filter, enable/disable, trip management, revenue, CSV export |
| 30 | NEW | `src/controllers/platformAdminController.broadcast.test.js` | A-020→027 | Send bulk notification, segment selection, history, global FCM on/off, per-union toggle, count display, sync verify |
| 31 | NEW | `src/controllers/platformAdminController.complaints.test.js` | A-028→034 | View/search/filter complaints, details, resolve, submit, my complaints |

### Phase 9: Background Jobs (SOP Part E-F)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 32 | NEW | `src/jobs/tripLifecycleJob.test.js` | BL-039→040 | Trip auto-start, trip auto-finish |
| 33 | NEW | `src/jobs/pendingBookingExpiryJob.test.js` | BL-041 | Pending booking auto-expire |
| 34 | NEW | `src/jobs/rideCleanupJob.test.js` | BL-042→045 | Trips after 7 days, DB health, backup command, VACUUM |
| 35 | NEW | `src/jobs/rateNotificationJob.test.js` | P-046, BL-029→030 | Auto rate reminder generation |
| 36 | NEW | `src/jobs/dailyStatsJob.test.js` | A-001→005 | Daily stats aggregation |

### Phase 10: Security & System (SOP Part E)

| # | New/Extend | File | SOP IDs | Tests |
|---|------------|------|---------|-------|
| 37 | NEW | `src/middleware/auth.test.js` | C-003, P-015→016 | Token refresh, session persistence, expired token |
| 38 | NEW | `src/middleware/rateLimiter.test.js` | C-004 | Rate limit enforcement per endpoint |
| 39 | NEW | `src/services/tokenService.test.js` | C-003 | Access/refresh token generation, validation, rotation |
| 40 | NEW | `src/services/otpService.test.js` | P-004→005, P-014 | OTP generation, hashing, verification, expiry |
| 41 | NEW | `src/services/emailService.test.js` | P-006, P-018 | Email sending, template formatting |

---

## Summary

| Metric | Count |
|--------|-------|
| Existing test files | 22 |
| New test files to create | 27 |
| Existing files to extend | 8 |
| Total test files after completion | 49 |
| SOP test cases coverable | ~180 / 250 (72%) |
| SOP tests needing real device/service | ~70 / 250 (28%) |
| Estimated new test count | ~350-400 new tests |
| Total tests after completion | ~550-600 |

## Cannot automate (need real infra/device)

| SOP IDs | Why |
|---------|-----|
| P-003 | Google Sign-In (real OAuth) |
| P-004 | Phone OTP (real Firebase) |
| P-034, P-035 | Call/WhatsApp (real device) |
| P-053 | FCM push (real device) |
| P-059→060 | Language switch (Flutter UI) |
| P-061→066 | Share, call, WhatsApp, terms, help (Flutter UI) |
| C-001→002 | Live seat update (2 real devices) |
| C-005 | Telegram alert (real Telegram) |
| C-006 | In-App Update (Play Store) |
| C-016→017 | Web/Android platform test |
| D-012 | Visual watermark verification |
| U-034→036 | Poster visual/share (PDF visual) |

These are covered by your `full-test-v2.js` (live API testing) and manual SOP testing.
