/**
 * driverVerificationController — pure gate helpers (P0).
 * driverVerificationController gatekeeps who may (re)submit KYC and become a
 * trip-creating driver, so the re-upload eligibility window and doc-url
 * sanitisation are regression-locked here.
 *
 * Pure-function unit test (no DB) — sanitizeKycUploadUrl is mocked so we test
 * only this controller's own logic. See SOP Part W, rule W3.
 */

jest.mock('../utils/sanitizeKycUploadUrl', () => ({
  // Identity-ish stub: trims, drops anything falsy/blank, rejects a sentinel.
  sanitizeKycUploadUrl: jest.fn((u) => {
    if (typeof u !== 'string') return null;
    const t = u.trim();
    if (!t || t === 'BAD') return null;
    return t;
  }),
}));

const {
  isDriverAllowedToReupload,
  orderedSanitizedDocUrls,
} = require('./driverVerificationController');

describe('isDriverAllowedToReupload — re-upload eligibility gate', () => {
  test('null / missing user row → not allowed', () => {
    expect(isDriverAllowedToReupload(null)).toBe(false);
    expect(isDriverAllowedToReupload(undefined)).toBe(false);
  });

  test('flag absent or not strictly true → not allowed', () => {
    expect(isDriverAllowedToReupload({})).toBe(false);
    expect(isDriverAllowedToReupload({ driver_kyc_reupload_allowed: false })).toBe(false);
    // truthy-but-not-true must NOT pass (=== true guard)
    expect(isDriverAllowedToReupload({ driver_kyc_reupload_allowed: 1 })).toBe(false);
    expect(isDriverAllowedToReupload({ driver_kyc_reupload_allowed: 'true' })).toBe(false);
  });

  test('allowed with no deadline → allowed (open-ended)', () => {
    expect(isDriverAllowedToReupload({ driver_kyc_reupload_allowed: true })).toBe(true);
    expect(isDriverAllowedToReupload({
      driver_kyc_reupload_allowed: true,
      driver_kyc_reupload_deadline: null,
    })).toBe(true);
  });

  test('allowed with a future deadline → allowed', () => {
    const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    expect(isDriverAllowedToReupload({
      driver_kyc_reupload_allowed: true,
      driver_kyc_reupload_deadline: future,
    })).toBe(true);
  });

  test('allowed but deadline already passed → not allowed', () => {
    const past = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    expect(isDriverAllowedToReupload({
      driver_kyc_reupload_allowed: true,
      driver_kyc_reupload_deadline: past,
    })).toBe(false);
  });

  test('unparseable deadline is ignored (treated as open-ended)', () => {
    // new Date('garbage').getTime() is NaN → Number.isFinite guard skips it
    expect(isDriverAllowedToReupload({
      driver_kyc_reupload_allowed: true,
      driver_kyc_reupload_deadline: 'not-a-date',
    })).toBe(true);
  });
});

describe('orderedSanitizedDocUrls — KYC url cleanup', () => {
  test('preserves order and drops blanks / invalid entries', () => {
    const out = orderedSanitizedDocUrls(['  a ', '', '  ', 'BAD', 'b']);
    expect(out).toEqual(['a', 'b']);
  });

  test('returns empty array for an all-invalid list', () => {
    expect(orderedSanitizedDocUrls(['', 'BAD', null])).toEqual([]);
  });

  test('returns empty array for an empty list', () => {
    expect(orderedSanitizedDocUrls([])).toEqual([]);
  });
});
