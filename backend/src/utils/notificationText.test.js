const { notifText, unionRideText, normLang } = require('./notificationText');

describe('notifText', () => {
  const keys = [
    'trip_auto_started',
    'booking_auto_cancelled',
    'booking_cancelled_ride_started',
    'trip_completed',
  ];

  test('returns a non-empty title + body for every key, in both languages', () => {
    for (const key of keys) {
      for (const lang of ['en', 'hi']) {
        const t = notifText(key, lang);
        expect(t).toBeTruthy();
        expect(typeof t.title).toBe('string');
        expect(t.title.length).toBeGreaterThan(0);
        expect(t.body.length).toBeGreaterThan(0);
      }
    }
  });

  // THE BUG WE FIXED: notifications used to cram English + Hindi into one message
  // joined by "·". A single rendered message must never contain BOTH scripts.
  test('no message mixes English and Devanagari (single language only)', () => {
    const devanagari = /[ऀ-ॿ]/;
    const latin = /[A-Za-z]/;
    for (const key of keys) {
      const en = notifText(key, 'en');
      expect(devanagari.test(en.title + en.body)).toBe(false);
      expect(en.title).not.toContain('·');
      expect(en.body).not.toContain('·');

      const hi = notifText(key, 'hi');
      // hi copy may include a brand/Latin word (e.g. "LuhaRide") but must not be
      // the old bilingual jam — guard the "·" separator specifically.
      expect(hi.title).not.toContain('·');
      expect(hi.body).not.toContain('·');
      expect(devanagari.test(hi.title + hi.body)).toBe(true);
    }
  });

  test('unknown / missing language falls back to English (never throws)', () => {
    const fallback = notifText('trip_completed', undefined);
    expect(fallback).toEqual(notifText('trip_completed', 'en'));
    expect(notifText('trip_completed', 'fr')).toEqual(notifText('trip_completed', 'en'));
  });

  test('unknown key returns null (callers fail loudly in tests, not prod)', () => {
    expect(notifText('does_not_exist', 'en')).toBeNull();
  });
});

describe('normLang', () => {
  test('only "hi" maps to Hindi; everything else is English', () => {
    expect(normLang('hi')).toBe('hi');
    expect(normLang('en')).toBe('en');
    expect(normLang(undefined)).toBe('en');
    expect(normLang('xx')).toBe('en');
  });
});

describe('unionRideText', () => {
  test('injects the union name and picks per-language copy', () => {
    const en = unionRideText('en', 1, 'Purola Union');
    expect(en.title).toContain('Purola Union');
    expect(en.title).not.toContain('{union}');
    expect(/[ऀ-ॿ]/.test(en.title)).toBe(false);

    const hi = unionRideText('hi', 1, 'Purola Union');
    expect(hi.title).toContain('Purola Union');
    expect(/[ऀ-ॿ]/.test(hi.body)).toBe(true);
  });

  test('day index wraps safely for any integer (0..6 and beyond)', () => {
    for (let d = -3; d <= 13; d++) {
      const t = unionRideText('en', d, 'U');
      expect(t.title.length).toBeGreaterThan(0);
      expect(t.body.length).toBeGreaterThan(0);
    }
  });
});
