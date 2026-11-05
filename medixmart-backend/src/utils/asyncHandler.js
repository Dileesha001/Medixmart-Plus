/**
 * Async handler utility to wrap async route handlers.
 * Catches rejected promises and forwards them to the Express error middleware.
 * @param {Function} fn - Async Express middleware/controller function
 * @returns {Function}
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = asyncHandler;

