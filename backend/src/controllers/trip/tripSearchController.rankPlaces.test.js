/**
 * rankPlaces — location-autocomplete ranking (the "right same-named place wins").
 * Pure function (real haversine, no network) — fast + deterministic.
 *
 * Real-ish coords used:
 *   Purola (near user)      ~ 30.88, 78.08
 *   Chandeli (Uttarkashi)   ~ 30.85, 78.12   (~5 km from Purola)
 *   Chandeli (Delhi area)   ~ 28.61, 77.21   (~250 km away)
 *   Mumbai                  ~ 19.07, 72.87   (clearly out of service area)
 *   Dehradun                ~ 30.31, 78.03
 */

const { rankPlaces } = require('./tripSearchController');

const PUROLA = { lat: 30.88, lng: 78.08 };
const chandeliUK = { description: 'Chandeli', secondary: 'Uttarkashi, Uttarakhand', lat: 30.85, lng: 78.12 };
const chandeliDL = { description: 'Chandeli', secondary: 'Delhi', lat: 28.61, lng: 77.21 };
const order = (places, opts) => rankPlaces(places, opts).map((p) => p.secondary);

describe('rankPlaces — proximity ranking', () => {
  test('same-named place: the nearby one ranks above the far one (GPS on)', () => {
    const ranked = order([chandeliDL, chandeliUK], { query: 'chandeli', near: PUROLA });
    expect(ranked[0]).toBe('Uttarkashi, Uttarakhand');
  });

  test('GPS OFF: the already-picked "from" is used as the reference → local wins', () => {
    // App passes the "from" coords as the picker bias, so even with GPS off the
    // nearest same-named place still wins — no hardcoded region needed.
    const ranked = order([chandeliDL, chandeliUK], { query: 'chandeli', near: PUROLA });
    expect(ranked[0]).toBe('Uttarkashi, Uttarakhand');
  });

  test('REGION-AGNOSTIC: works anywhere in India, not just Uttarakhand', () => {
    // A user near Mumbai searching a duplicate name must get THEIR local place
    // first — the algorithm must never be biased toward Uttarakhand.
    const MUMBAI = { lat: 19.07, lng: 72.87 };
    const placeMH = { description: 'Andheri', secondary: 'Mumbai, Maharashtra', lat: 19.12, lng: 72.85 };
    const placeFar = { description: 'Andheri', secondary: 'Somewhere, Uttarakhand', lat: 30.85, lng: 78.12 };
    const ranked = rankPlaces([placeFar, placeMH], { query: 'andheri', near: MUMBAI });
    expect(ranked[0].secondary).toBe('Mumbai, Maharashtra');
  });

  test('no reference at all → neutral text ranking, NO region penalty', () => {
    // With no GPS and no "from", nothing is demoted by region — both stay (the
    // visible district/state label lets the user choose). Order is text-based.
    const ranked = rankPlaces([chandeliDL, chandeliUK], { query: 'chandeli', near: undefined });
    expect(ranked).toHaveLength(2); // neither hidden nor region-penalised
  });

  test('input order does not matter — nearest still wins', () => {
    const a = order([chandeliUK, chandeliDL], { query: 'chandeli', near: PUROLA });
    const b = order([chandeliDL, chandeliUK], { query: 'chandeli', near: PUROLA });
    expect(a[0]).toBe('Uttarkashi, Uttarakhand');
    expect(b[0]).toBe('Uttarkashi, Uttarakhand');
  });
});

describe('rankPlaces — text relevance still leads', () => {
  test('an EXACT text match beats a merely-nearer starts-with match', () => {
    const delhi = { description: 'Delhi', secondary: 'Delhi', lat: 28.61, lng: 77.21 };
    const dehradun = { description: 'Dehradun', secondary: 'Uttarakhand', lat: 30.31, lng: 78.03 };
    // query "delhi": "Delhi" is exact (rank 0) and must win over the nearer "Dehradun"
    const ranked = rankPlaces([dehradun, delhi], { query: 'delhi', near: PUROLA });
    expect(ranked[0].description).toBe('Delhi');
  });
});

describe('rankPlaces — far places demoted by proximity (not hidden)', () => {
  test('a place far from the user is demoted below a nearby one', () => {
    const mumbai = { description: 'Station', secondary: 'Mumbai', lat: 19.07, lng: 72.87 };
    const local = { description: 'Station', secondary: 'Uttarkashi', lat: 30.85, lng: 78.12 };
    const ranked = order([mumbai, local], { query: 'station', near: PUROLA });
    expect(ranked[0]).toBe('Uttarkashi'); // nearer to the Purola reference
    expect(ranked[1]).toBe('Mumbai');
  });

  test('a far place is never HIDDEN — a genuine long-distance destination still appears', () => {
    const mumbai = { description: 'Mumbai', secondary: 'Maharashtra', lat: 19.07, lng: 72.87 };
    const ranked = rankPlaces([mumbai], { query: 'mumbai', near: PUROLA });
    expect(ranked).toHaveLength(1);
    expect(ranked[0].description).toBe('Mumbai');
  });
});

describe('rankPlaces — coordless entries', () => {
  test('within the same text rank, a coord-backed nearby place beats a coordless one', () => {
    const coordless = { description: 'Chandeli', secondary: 'Uttarakhand', lat: null, lng: null };
    const ranked = rankPlaces([coordless, chandeliUK], { query: 'chandeli', near: PUROLA });
    expect(ranked[0].lat).not.toBeNull(); // the coord-backed nearby one first
  });

  test('does not throw on empty input', () => {
    expect(rankPlaces([], { query: 'x', near: PUROLA })).toEqual([]);
  });
});
