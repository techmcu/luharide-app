/**
 * Pagination constants – single source of truth for scaling and consistency
 * Used by reviews, notifications, and any list endpoints
 */
const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 50;

/** Reviews list: BlaBlaCar-style smaller pages; all rows kept in DB, only paginated in API. */
const DEFAULT_REVIEW_PAGE_SIZE = 20;
const MAX_REVIEW_PAGE_SIZE = 30;

function clampPage(page) {
  return Math.max(1, parseInt(page, 10) || 1);
}

function clampLimit(limit) {
  return Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(limit, 10) || DEFAULT_PAGE_SIZE));
}

function clampReviewLimit(limit) {
  return Math.min(
    MAX_REVIEW_PAGE_SIZE,
    Math.max(1, parseInt(limit, 10) || DEFAULT_REVIEW_PAGE_SIZE)
  );
}

function offset(page, limit) {
  return (page - 1) * limit;
}

module.exports = {
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  DEFAULT_REVIEW_PAGE_SIZE,
  MAX_REVIEW_PAGE_SIZE,
  clampPage,
  clampLimit,
  clampReviewLimit,
  offset,
};
