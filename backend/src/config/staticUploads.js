const express = require('express');

/** Browser / WebView can cache aggressively; reduces repeat bandwidth for the same KYC file. */
const UPLOADS_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

function mountUploadsStatic(app, absoluteUploadsDir) {
  // CORS + Private Network Access for /uploads (Flutter web XHR needs this)
  app.use('/uploads', (req, res, next) => {
    const origin = req.headers.origin || '*';
    
    // Echo origin for dev (localhost) + prod domains
    if (
      origin === '*' ||
      origin.includes('luharide.cloud') ||
      origin.includes('localhost') ||
      origin.includes('127.0.0.1')
    ) {
      res.setHeader('Access-Control-Allow-Origin', origin);
    } else {
      res.setHeader('Access-Control-Allow-Origin', '*');
    }
    
    res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, Range');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range, ETag');
    res.setHeader('Vary', 'Origin');
    
    // Chrome Private Network Access (localhost Flutter web → remote VPS)
    const pna = req.headers['access-control-request-private-network'];
    if (String(pna).toLowerCase() === 'true') {
      res.setHeader('Access-Control-Allow-Private-Network', 'true');
    }
    
    if (req.method === 'OPTIONS') {
      return res.status(204).end();
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
