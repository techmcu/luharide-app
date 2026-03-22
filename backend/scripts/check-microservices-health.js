#!/usr/bin/env node
/**
 * Phase 1 — verify gateway + 4 microservices /health
 * Usage (from backend/): npm run check:ms
 */
const http = require('http');

const checks = [
  { name: 'auth', port: process.env.AUTH_SERVICE_PORT || 3001, path: '/health' },
  { name: 'core', port: process.env.CORE_SERVICE_PORT || 3002, path: '/health' },
  { name: 'union', port: process.env.UNION_SERVICE_PORT || 3003, path: '/health' },
  { name: 'platform', port: process.env.PLATFORM_SERVICE_PORT || 3004, path: '/health' },
  { name: 'gateway', port: process.env.GATEWAY_PORT || process.env.PORT || 3000, path: '/health' },
];

function get(url) {
  return new Promise((resolve, reject) => {
    const req = http.get(url, (res) => {
      let body = '';
      res.on('data', (c) => {
        body += c;
      });
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('timeout'));
    });
  });
}

(async () => {
  console.log('LuhaRide microservices health (Phase 1)\n');
  let ok = true;
  for (const c of checks) {
    const url = `http://127.0.0.1:${c.port}${c.path}`;
    try {
      const r = await get(url);
      const good = r.status === 200;
      console.log(`${good ? 'OK  ' : 'FAIL'} ${c.name.padEnd(10)} ${url} → HTTP ${r.status}`);
      if (!good) ok = false;
    } catch (e) {
      console.log(`FAIL ${c.name.padEnd(10)} ${url} → ${e.message}`);
      ok = false;
    }
  }
  console.log(ok ? '\nPhase 1: all checks passed.' : '\nPhase 1: some checks failed. Is `npm run dev:stack` running?');
  process.exit(ok ? 0 : 1);
})();
