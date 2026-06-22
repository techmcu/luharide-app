/**
 * Fare service — distance-based fare CEILING for shared rides.
 *
 * Model (per seat):
 *   fair (internal) = baseFare + perKm × distanceKm
 *   maxAllowed      = fair × maxMultiplier
 * The flat `baseFare` makes the *effective* ₹/km higher on short rides and lower
 * on long ones — matching real Uttarakhand shared fares (≈₹8–10/km for a few km,
 * ≈₹2.8–3/km for 145 km+). No tiers, no discontinuities; it auto-adjusts.
 *
 * Driver UX: the driver simply types a price. We DO NOT show them the fair /
 * suggested value — only the ceiling matters. They may price as LOW as they
 * like (their choice); they CANNOT exceed `maxAllowed` (anti-overcharge guard).
 *
 * `fair` is kept internal (for admin/analytics); `validateFare` never leaks it
 * to the driver — on rejection it reveals only the max allowed.
 *
 * All knobs come from config (env-overridable). Pure functions, never throw —
 * invalid input → null estimate / 'unknown' status so the caller stays safe.
 */
const { config } = require('../config/env');

const F = config.fare;

/** Round to nearest `step` (e.g. 5 → 446 → 445). Guards against bad step. */
function roundTo(value, step) {
  const s = step > 0 ? step : 1;
  return Math.round(value / s) * s;
}

function toNum(v) {
  const n = typeof v === 'number' ? v : parseFloat(v);
  return Number.isFinite(n) ? n : NaN;
}

/**
 * Compute the internal fair price and the enforced ceiling for a distance.
 * @param {number} distanceKm road distance in km
 * @returns {{distanceKm,fair,max,perKmEffective}|null} null if distance invalid
 */
function estimateFare(distanceKm) {
  const km = toNum(distanceKm);
  if (!Number.isFinite(km) || km <= 0 || km > 5000) return null; // sane bounds

  const rawFair = F.baseFare + km * F.perKm;
  const fair = Math.max(F.minFare, roundTo(rawFair, F.roundTo));
  const max = Math.max(fair, roundTo(fair * F.maxMultiplier, F.roundTo));

  return {
    distanceKm: +km.toFixed(1),
    fair,
    max,
    perKmEffective: +(fair / km).toFixed(2), // for admin insight only
  };
}

/**
 * Validate a driver-entered fare against the ceiling for a distance.
 * Driver-safe: reveals only `maxAllowed`, never the internal fair price.
 * @returns {{status:'ok'|'over'|'unknown'|'invalid', message:string, maxAllowed:number|null}}
 *   'unknown' → no distance available, can't judge → caller should allow it.
 */
function validateFare(enteredFare, distanceKm) {
  const fare = toNum(enteredFare);
  if (!Number.isFinite(fare) || fare < 0) {
    return { status: 'invalid', message: 'Enter a valid fare amount.', maxAllowed: null };
  }

  const est = estimateFare(distanceKm);
  if (!est) {
    return { status: 'unknown', message: '', maxAllowed: null };
  }

  if (fare > est.max) {
    return {
      status: 'over',
      message: `Maximum fare for ~${est.distanceKm} km is ₹${est.max}. Please enter ₹${est.max} or less.`,
      maxAllowed: est.max,
    };
  }
  // Anything at or below the ceiling is accepted — low prices are the driver's call.
  return { status: 'ok', message: '', maxAllowed: est.max };
}

module.exports = {
  estimateFare,
  validateFare,
  roundTo,
};
