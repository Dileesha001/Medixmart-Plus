/**
 * 404 Not Found Route Middleware.
 * Catches all unhandled routes and returns standard error envelope.
 */
const { errorResponse } = require('../utils/response');

const notFoundHandler = (req, res) => {
  return errorResponse(
    res,
    'ROUTE_NOT_FOUND',
    `The requested endpoint '${req.method} ${req.originalUrl}' does not exist on this server.`,
    404
  );
};

module.exports = notFoundHandler;

