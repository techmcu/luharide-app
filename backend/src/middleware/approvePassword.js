const ApiError = require('../utils/ApiError');

// Approve endpoints are sensitive. Require an explicit password so approvals
// don't happen accidentally or by leaked token.
function requireApprovePassword(req, res, next) {
  const expected = process.env.ADMIN_APPROVE_PASSWORD;
  if (!expected || String(expected).trim().length < 6) {
    // Misconfigured server: don't allow approvals without password configured.
    return next(ApiError.internal('Admin approval password is not configured on server'));
  }

  const provided =
    req.headers['x-approve-password'] ||
    req.headers['x-admin-approve-password'] ||
    req.body?.approve_password ||
    req.body?.password;

  if (!provided || String(provided) !== String(expected)) {
    return next(ApiError.forbidden('Invalid admin approval password'));
  }

  return next();
}

module.exports = { requireApprovePassword };

