const ola = require('./olaMapsService');

describe('olaMapsService geometry (no PostGIS corridor matching)', () => {
  it('validates coordinates', () => {
    expect(ola.isValidLatLng(30.3, 78.0)).toBe(true);
    expect(ola.isValidLatLng(91, 0)).toBe(false);
    expect(ola.isValidLatLng('x', 0)).toBe(false);
    expect(ola.isValidLatLng(NaN, NaN)).toBe(false);
  });

  it('haversine gives a sane distance and Infinity for bad input', () => {
    const d = ola.haversineKm(30.3165, 78.0322, 30.4599, 78.0664); // Dehradun→Mussoorie
    expect(d).toBeGreaterThan(10);
    expect(d).toBeLessThan(25);
    expect(ola.haversineKm(NaN, 0, 0, 0)).toBe(Infinity);
  });

  it('decodes an encoded polyline and tolerates junk', () => {
    const pts = ola.decodePolyline('_p~iF~ps|U_ulLnnqC');
    expect(pts.length).toBe(2);
    expect(pts[0][0]).toBeCloseTo(38.5, 1);
    expect(ola.decodePolyline('')).toEqual([]);
    expect(ola.decodePolyline(null)).toEqual([]);
  });

  it('downsamples long polylines but keeps short ones', () => {
    const long = Array.from({ length: 500 }, (_, i) => [30 + i * 0.001, 78]);
    expect(ola.downsamplePolyline(long, 80).length).toBe(80);
    expect(ola.downsamplePolyline([[1, 2], [3, 4]], 80).length).toBe(2);
  });

  it('projects on-route points with ~0 distance and correct travel order', () => {
    const line = [[30.3165, 78.0322], [30.22, 78.78], [30.55, 79.56]]; // Dehradun→Srinagar→Joshimath
    const origin = ola.projectOntoPolyline(30.22, 78.78, line);   // Srinagar (on route)
    const dest = ola.projectOntoPolyline(30.55, 79.56, line);     // Joshimath (end)
    expect(origin.distKm).toBeLessThan(1);
    expect(dest.distKm).toBeLessThan(1);
    expect(origin.alongKm).toBeLessThan(dest.alongKm); // direction: origin before dest
  });

  it('flags off-route points as far from the line', () => {
    const line = [[30.3165, 78.0322], [30.22, 78.78], [30.55, 79.56]];
    const off = ola.projectOntoPolyline(29.38, 79.45, line); // Nainital — off route
    expect(off.distKm).toBeGreaterThan(50);
  });

  it('getRouteDistance falls back to a straight line with points+bbox when disabled', async () => {
    const r = await ola.getRouteDistance({ lat: 30.3165, lng: 78.0322 }, { lat: 30.4599, lng: 78.0664 });
    expect(r).not.toBeNull();
    expect(r.estimated).toBe(true);
    expect(Array.isArray(r.points)).toBe(true);
    expect(r.bbox).toHaveProperty('minLat');
    expect(await ola.getRouteDistance({ lat: 200, lng: 0 }, { lat: 0, lng: 0 })).toBeNull();
  });
});
