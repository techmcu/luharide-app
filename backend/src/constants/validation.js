/**
 * Validation constants – business rules in one place
 * OOP: single responsibility for domain rules
 */
const RATING = {
  MIN: 1,
  MAX: 5,
};

const RATING_COMMENT_MAX_WORDS = 20;

const ROLES = {
  PASSENGER: 'passenger',
  DRIVER: 'driver',
};

module.exports = {
  RATING,
  RATING_COMMENT_MAX_WORDS,
  ROLES,
};
