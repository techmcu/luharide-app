/**
 * Central security tuning — single source of truth for password hashing cost.
 *
 * Why this file exists:
 * - All password hashing must use the SAME bcrypt cost factor. Hardcoding the
 *   number in multiple controllers risks drift (one place changes, others don't).
 * - bcrypt.compare() reads the cost from the stored hash, so LOWERING this value
 *   does NOT break existing users — old `$2a$12$...` hashes keep verifying fine.
 *   New hashes use the new cost. No migration, no lock-outs.
 *
 * Cost trade-off (on the production single-vCPU box this matters a lot):
 * - 12 ≈ 4x slower per hash than 10. On 1 vCPU that throttles login/signup.
 * - 10 is still a strong, industry-standard cost (used widely in production).
 *
 * Override via BCRYPT_ROUNDS env if ever needed. Clamped to [10, 14] so a bad
 * env value can never make hashing insecure (<10) or absurdly slow (>14).
 */
const DEFAULT_BCRYPT_ROUNDS = 10;
const MIN_BCRYPT_ROUNDS = 10;
const MAX_BCRYPT_ROUNDS = 14;

function resolveBcryptRounds() {
  const raw = parseInt(process.env.BCRYPT_ROUNDS, 10);
  if (!Number.isInteger(raw)) return DEFAULT_BCRYPT_ROUNDS;
  return Math.min(MAX_BCRYPT_ROUNDS, Math.max(MIN_BCRYPT_ROUNDS, raw));
}

const BCRYPT_ROUNDS = resolveBcryptRounds();

module.exports = { BCRYPT_ROUNDS };
