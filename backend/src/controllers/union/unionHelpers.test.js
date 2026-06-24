/**
 * Unit tests for union/poster pure helpers.
 *
 * These cover user-facing union poster + name sanitization logic that previously
 * had no test. All functions here are pure (no DB), so the tests are fast and
 * cannot flake. The DB helpers (demote/unlink) are intentionally left to the
 * integration layer — see docs/testing SOP "Union admin lifecycle" scenarios.
 */
const {
  cleanUnionName,
  cleanPosterHeader,
  cleanPosterCustomText,
  getPosterTheme,
  getPosterThemeColors,
} = require('./unionHelpers');

describe('cleanUnionName', () => {
  it('falls back to "Taxi Union" for empty/blank/null input', () => {
    expect(cleanUnionName(null)).toBe('Taxi Union');
    expect(cleanUnionName(undefined)).toBe('Taxi Union');
    expect(cleanUnionName('')).toBe('Taxi Union');
    expect(cleanUnionName('   ')).toBe('Taxi Union');
    expect(cleanUnionName('\n\t  ')).toBe('Taxi Union');
  });

  it('keeps a normal name and collapses extra whitespace', () => {
    expect(cleanUnionName('Dehradun  Taxi   Union')).toBe('Dehradun Taxi Union');
    expect(cleanUnionName('  Purola Taxi Union  ')).toBe('Purola Taxi Union');
  });

  it('strips control characters', () => {
    expect(cleanUnionName('Dehradun\x00 Taxi\x7F Union')).toBe('Dehradun Taxi Union');
  });

  it('drops tokens that contain no letters when letter-tokens exist', () => {
    // "123" has no letter and is dropped because "Taxi"/"Union" carry letters
    expect(cleanUnionName('123 Taxi 456 Union')).toBe('Taxi Union');
  });

  it('preserves Devanagari (Hindi) names', () => {
    expect(cleanUnionName('टैक्सी यूनियन')).toBe('टैक्सी यूनियन');
  });

  it('coerces non-string input safely', () => {
    expect(cleanUnionName(12345)).toBe('12345');
  });
});

describe('cleanPosterHeader', () => {
  it('returns empty string for blank/null', () => {
    expect(cleanPosterHeader(null)).toBe('');
    expect(cleanPosterHeader('')).toBe('');
    expect(cleanPosterHeader('   ')).toBe('');
  });

  it('strips control chars and collapses whitespace', () => {
    expect(cleanPosterHeader('  Welcome\x00  Riders  ')).toBe('Welcome Riders');
  });
});

describe('cleanPosterCustomText', () => {
  it('returns empty string for blank/null', () => {
    expect(cleanPosterCustomText(null)).toBe('');
    expect(cleanPosterCustomText('')).toBe('');
  });

  it('strips control chars and collapses whitespace', () => {
    expect(cleanPosterCustomText('Book\x07 your\n seat')).toBe('Book your seat');
  });

  it('truncates to 120 characters (poster overflow guard)', () => {
    const long = 'a'.repeat(200);
    expect(cleanPosterCustomText(long)).toHaveLength(120);
  });
});

describe('getPosterTheme', () => {
  it('returns each known theme as-is', () => {
    for (const t of ['saffron', 'sky', 'mint', 'rose']) {
      expect(getPosterTheme(t)).toBe(t);
    }
  });

  it('is case-insensitive and trims', () => {
    expect(getPosterTheme('  SKY ')).toBe('sky');
    expect(getPosterTheme('Mint')).toBe('mint');
  });

  it('falls back to "saffron" for unknown/blank/null', () => {
    expect(getPosterTheme('purple')).toBe('saffron');
    expect(getPosterTheme('')).toBe('saffron');
    expect(getPosterTheme(null)).toBe('saffron');
    expect(getPosterTheme(undefined)).toBe('saffron');
  });
});

describe('getPosterThemeColors', () => {
  it('returns the palette object for a known theme', () => {
    const sky = getPosterThemeColors('sky');
    expect(sky).toEqual(
      expect.objectContaining({ headerBg: expect.any(String), text: expect.any(String) })
    );
  });

  it('falls back to the saffron palette for unknown themes', () => {
    expect(getPosterThemeColors('nope')).toEqual(getPosterThemeColors('saffron'));
  });

  it('every known theme yields a full color set', () => {
    for (const t of ['saffron', 'sky', 'mint', 'rose']) {
      const c = getPosterThemeColors(t);
      expect(c).toHaveProperty('headerBg');
      expect(c).toHaveProperty('topStripe');
      expect(c).toHaveProperty('text');
      expect(c).toHaveProperty('subText');
    }
  });
});

describe('ensurePlatformAdmin', () => {
  // adminEmail is captured from process.env at module load, so require a fresh
  // copy with ADMIN_EMAIL set.
  let helpers;
  const OLD = process.env.ADMIN_EMAIL;
  beforeAll(() => {
    process.env.ADMIN_EMAIL = 'Boss@LuhaRide.com';
    jest.resetModules();
    helpers = require('./unionHelpers');
  });
  afterAll(() => {
    process.env.ADMIN_EMAIL = OLD;
    jest.resetModules();
  });

  it('allows the configured admin (case-insensitive, trimmed)', () => {
    expect(() => helpers.ensurePlatformAdmin({ email: '  boss@luharide.com ' })).not.toThrow();
  });

  it('rejects a non-admin user', () => {
    expect(() => helpers.ensurePlatformAdmin({ email: 'rider@x.com' })).toThrow(
      /Only app admin/
    );
  });

  it('rejects null / email-less users', () => {
    expect(() => helpers.ensurePlatformAdmin(null)).toThrow();
    expect(() => helpers.ensurePlatformAdmin({})).toThrow();
  });
});
