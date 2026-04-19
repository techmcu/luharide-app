const express = require('express');

/** Browser / WebView can cache aggressively; reduces repeat bandwidth for the same KYC file. */
const UPLOADS_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

function mountUploadsStatic(app, absoluteUploadsDir) {
  // CORS headers for static uploads (Flutter web + mobile webview)
  app.use('/uploads', (req, res, next) => {
    const origin = req.headers.origin;
    // Allow common origins + localhost dev
    if (
      origin &&
      (origin.includes('luharide.cloud') ||
        origin.includes('localhost') ||
        origin.includes('127.0.0.1'))
    ) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      res.setHeader('Access-Control-Allow-Credentials', 'true');
      res.setHeader('Access-Control-Max-Age', '86400');
    }
    if (req.method === 'OPTIONS') {
      return res.sendStatus(204);
    }
    next();
  });

  app.use(
    '/uploads',
    express.static(absoluteUploadsDir, {
      maxAge: UPLOADS_MAX_AGE_MS,
      immutable: true,
      etag: true,
      lastModified: true,
    })
  );
}

module.exports = { mountUploadsStatic, UPLOADS_MAX_AGE_MS };
