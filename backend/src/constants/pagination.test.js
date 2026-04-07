const {
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  DEFAULT_REVIEW_PAGE_SIZE,
  MAX_REVIEW_PAGE_SIZE,
  clampPage,
  clampLimit,
  clampReviewLimit,
  offset,
} = require('./pagination');

describe('pagination', () => {
  describe('clampPage', () => {
    it('defaults invalid and sub-1 to 1', () => {
      expect(clampPage(undefined)).toBe(1);
      expect(clampPage(null)).toBe(1);
      expect(clampPage('')).toBe(1);
      expect(clampPage(0)).toBe(1);
      expect(clampPage(-3)).toBe(1);
    });

    it('parses positive integers', () => {
      expect(clampPage('5')).toBe(5);
      expect(clampPage(12)).toBe(12);
    });
  });

  describe('clampLimit', () => {
    it(`defaults to ${DEFAULT_PAGE_SIZE} when missing or invalid`, () => {
      expect(clampLimit(undefined)).toBe(DEFAULT_PAGE_SIZE);
      expect(clampLimit('')).toBe(DEFAULT_PAGE_SIZE);
    });

    it('floors at 1', () => {
      expect(clampLimit(0)).toBe(DEFAULT_PAGE_SIZE);
    });

    it(`caps at ${MAX_PAGE_SIZE}`, () => {
      expect(clampLimit(999)).toBe(MAX_PAGE_SIZE);
      expect(clampLimit(String(MAX_PAGE_SIZE + 10))).toBe(MAX_PAGE_SIZE);
    });
  });

  describe('clampReviewLimit', () => {
    it(`defaults to ${DEFAULT_REVIEW_PAGE_SIZE}`, () => {
      expect(clampReviewLimit(undefined)).toBe(DEFAULT_REVIEW_PAGE_SIZE);
    });

    it(`caps at ${MAX_REVIEW_PAGE_SIZE}`, () => {
      expect(clampReviewLimit(1000)).toBe(MAX_REVIEW_PAGE_SIZE);
    });
  });

  describe('offset', () => {
    it('computes (page-1)*limit', () => {
      expect(offset(1, 20)).toBe(0);
      expect(offset(3, 10)).toBe(20);
    });
  });
});
