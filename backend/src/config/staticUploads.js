const express = require('express');

/** Browser / WebView can cache aggressively; reduces repeat bandwidth for the same KYC file. */
const UPLOADS_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

function mountUploadsStatic(app, absoluteUploadsDir) {
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
