/**
 * Unit tests for the pure search helpers in tripSearchController.
 *
 * geoBoundingBox powers the indexed SQL pre-filter for proximity ("rides near
 * you") search — the assessment flagged JS-side geo/scoring as a scale concern,
 * so its math is worth locking down. requireUuid guards trip-id inputs.
 * Both are pure (no DB/network), so these tests are fast and deterministic.
 */
const { geoBoundingBox, requireUuid } = require('./tripSearchController');

describe('geoBoundingBox', () => {
  it('produces a box centered on the point', () => {
    const lat = 30.3165;
    const lng = 78.0322; // Dehradun
    const box = geoBoundingBox(lat, lng, 10);
    expect(box.latMin).toBeLessThan(lat);
    expect(box.latMax).toBeGreaterThan(lat);
    expect(box.lngMin).toBeLessThan(lng);
    expect(box.lngMax).toBeGreaterThan(lng);
    // Symmetric in latitude
    expect(lat - box.latMin).toBeCloseTo(box.latMax - lat, 6);
  });

  it('uses ~111 km per degree of latitude', () => {
    const box = geoBoundingBox(0, 0, 111);
    expect(box.latMax - box.latMin).toBeCloseTo(2, 3); // ±1 degree for 111 km
  });

  it('widens the longitude span as latitude increases (cos correction)', () => {
    const radius = 50;
    const equator = geoBoundingBox(0, 0, radius);
    const north = geoBoundingBox(60, 0, radius);
    const eqLngSpan = equator.lngMax - equator.lngMin;
    const northLngSpan = north.lngMax - north.lngMin;
    // At 60° latitude, cos ≈ 0.5, so the degree span is ~2x the equator span.
    expect(northLngSpan).toBeGreaterThan(eqLngSpan * 1.8);
  });

  it('clamps the cos factor near the poles so longitude span stays finite', () => {
    const box = geoBoundingBox(89.9, 0, 50);
    expect(Number.isFinite(box.lngMin)).toBe(true);
    expect(Number.isFinite(box.lngMax)).toBe(true);
    // cos is floored at 0.1 → span never blows up to infinity
    expect(box.lngMax - box.lngMin).toBeLessThan(20);
  });

  it('scales the box with the radius', () => {
    const small = geoBoundingBox(30, 78, 5);
    const big = geoBoundingBox(30, 78, 50);
    expect(big.latMax - big.latMin).toBeGreaterThan(small.latMax - small.latMin);
  });
});

describe('requireUuid', () => {
  it('accepts a valid v4-shaped UUID', () => {
    expect(() => requireUuid('3f2504e0-4f89-41d3-9a0c-0305e82c3301')).not.toThrow();
  });

  it('accepts uppercase UUIDs (case-insensitive)', () => {
    expect(() => requireUuid('3F2504E0-4F89-41D3-9A0C-0305E82C3301')).not.toThrow();
  });

  it('rejects malformed / missing ids with a 400-style error', () => {
    for (const bad of ['', null, undefined, 'not-a-uuid', '12345', '3f2504e0-4f89-41d3-9a0c']) {
      expect(() => requireUuid(bad)).toThrow(/Invalid trip ID/);
    }
  });
});
