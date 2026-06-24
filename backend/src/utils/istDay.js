/**
 * Start of "today" in India Standard Time (Asia/Kolkata) as a timestamptz —
 * for daily-limit windows.
 *
 * The DB server runs in UTC, so plain `CURRENT_DATE` rolls the day over at
 * 00:00 UTC = 05:30 IST. For an India-only app that's wrong: a ride made at
 * 00:10 IST was counted against the PREVIOUS day, so yesterday's actions still
 * blocked "today" until 05:30. This expression rolls over at IST midnight.
 *
 * It's a constant SQL fragment (no user input) — safe to interpolate.
 */
const IST_TODAY_START = `timezone('Asia/Kolkata', date_trunc('day', timezone('Asia/Kolkata', NOW())))`;

module.exports = { IST_TODAY_START };
