/** Shared copy for KYC image + PDF watermarks (driver + union uploads). */
const LINE_PRIMARY = 'Verified by LuhaRide';
/** Legal-style disclaimer (English). Hindi in PDF needs an embedded Devanagari font file. */
const LINE_SECONDARY =
  'Uploaded only for LuhaRide account / KYC on this platform. Not for any other use or purpose.';
/** Large faint mark at top of each page (PDF) / image. */
const LINE_TOP_MARK = 'VERIFY';

module.exports = { LINE_PRIMARY, LINE_SECONDARY, LINE_TOP_MARK };
