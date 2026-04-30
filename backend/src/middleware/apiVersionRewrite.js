function apiVersionRewrite(req, res, next) {
  if (req.url.startsWith('/api/v1/')) {
    req.url = '/api/' + req.url.slice(8);
  } else if (req.url === '/api/v1') {
    req.url = '/api';
  }
  next();
}

module.exports = { apiVersionRewrite };
