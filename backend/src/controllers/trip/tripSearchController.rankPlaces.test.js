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

describe('rankPlaces — nearest same-name wins regardless of word position', () => {
  test('a FAR "starts-with" match never outranks a NEARER "contains" match', () => {
    // The original bug: "Naugaon Waiting Hall" (name starts with the query but is
    // far) beat "Manduwala Chowk Naugaon" (nearer, query is a later word). For
    // setting From/To the user wants their CLOSEST same-named place on top.
    const farStartsWith = { description: 'Naugaon Waiting Hall', secondary: 'Delhi area', lat: 28.61, lng: 77.21 }; // ~250 km
    const nearContains = { description: 'Manduwala Chowk Naugaon', secondary: 'Uttarkashi', lat: 30.85, lng: 78.12 }; // ~5 km
    const ranked = rankPlaces([farStartsWith, nearContains], { query: 'naugaon', near: PUROLA });
    expect(ranked[0].secondary).toBe('Uttarkashi'); // nearest first
  });

  test('among many same-named places, order is strictly nearest → farthest', () => {
    const near = { description: 'Naugaon', secondary: 'near', lat: 30.85, lng: 78.12 };   // ~5 km
    const mid = { description: 'Naugaon', secondary: 'mid', lat: 30.31, lng: 78.03 };     // ~65 km (Dehradun)
    const far = { description: 'Naugaon', secondary: 'far', lat: 28.61, lng: 77.21 };      // ~250 km (Delhi)
    const ranked = rankPlaces([far, mid, near], { query: 'naugaon', near: PUROLA });
    expect(ranked.map((p) => p.secondary)).toEqual(['near', 'mid', 'far']);
  });

  test('a coordless same-name entry sinks BELOW a far coord-backed one', () => {
    const coordless = { description: 'Naugaon Barkot Road', secondary: 'uk-nocoord', lat: null, lng: null };
    const farCoord = { description: 'Naugaon City', secondary: 'far-coord', lat: 28.61, lng: 77.21 };
    const ranked = rankPlaces([coordless, farCoord], { query: 'naugaon', near: PUROLA });
    expect(ranked[0].secondary).toBe('far-coord'); // coord-backed beats coordless even if far
  });

  test('exact name still beats any nearer non-exact match', () => {
    const exactFar = { description: 'Noida', secondary: 'exact', lat: 28.57, lng: 77.32 };
    const nearPartial = { description: 'Greater Noida West', secondary: 'partial-near', lat: 30.85, lng: 78.12 };
    const ranked = rankPlaces([nearPartial, exactFar], { query: 'noida', near: PUROLA });
    expect(ranked[0].secondary).toBe('exact'); // exact name wins over a nearer partial
  });
});
