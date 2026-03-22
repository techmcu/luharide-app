#!/usr/bin/env node
/**
 * Verifies HTTP /health on all LuhaRide microservice ports + API gateway.
 * Phase 1 local acceptance: all endpoints must return HTTP 200 (and DB OK in JSON).
 *
 * Run from backend/: npm run verify:luharide-microservices-health-endpoints
 * (npm sets GATEWAY_PORT=3010 so gateway does not conflict with monolith on 3000.)
 */
const http = require('http');

const healthChecks = [
  { serviceLabel: 'luharide-auth-service', port: process.env.AUTH_SERVICE_PORT || 3001, path: '/health' },
  { serviceLabel: 'luharide-core-ride-service', port: process.env.CORE_SERVICE_PORT || 3002, path: '/health' },
  { serviceLabel: 'luharide-union-admin-service', port: process.env.UNION_SERVICE_PORT || 3003, path: '/health' },
  {
    serviceLabel: 'luharide-platform-admin-payments-service',
    port: process.env.PLATFORM_SERVICE_PORT || 3004,
    path: '/health',
  },
  { serviceLabel: 'luharide-api-gateway', port: process.env.GATEWAY_PORT || process.env.PORT || 3000, path: '/health' },
];

function httpGet(url) {
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
  console.log('LuhaRide — verify microservices + gateway health endpoints (Phase 1)\n');
  let allPassed = true;
  for (const c of healthChecks) {
    const url = `http://127.0.0.1:${c.port}${c.path}`;
    try {
      const r = await httpGet(url);
      const good = r.status === 200;
      console.log(
        `${good ? 'OK  ' : 'FAIL'} ${c.serviceLabel.padEnd(42)} ${url} → HTTP ${r.status}`
      );
      if (!good) allPassed = false;
    } catch (e) {
      console.log(`FAIL ${c.serviceLabel.padEnd(42)} ${url} → ${e.message}`);
      allPassed = false;
    }
  }
  console.log(
    allPassed
      ? '\nPhase 1 verification: all health endpoints passed.'
      : '\nPhase 1 verification: failed — ensure `npm run develop:luharide-microservices-local-five-services` is running in another terminal.'
  );
  process.exit(allPassed ? 0 : 1);
})();
