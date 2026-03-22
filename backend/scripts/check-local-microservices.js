/**
 * Quick check: is the gateway + 4 microservices accepting HTTP?
 * Usage: node scripts/check-local-microservices.js
 * Env: GATEWAY_PORT (default 3010), AUTH_SERVICE_PORT (3001), ...
 */
const http = require('http');

const GW = parseInt(process.env.GATEWAY_PORT || '3010', 10);
const CHECKS = [
  ['gateway /health', `http://127.0.0.1:${GW}/health`],
  ['auth /health', `http://127.0.0.1:${process.env.AUTH_SERVICE_PORT || '3001'}/health`],
  ['core /health', `http://127.0.0.1:${process.env.CORE_SERVICE_PORT || '3002'}/health`],
  ['union /health', `http://127.0.0.1:${process.env.UNION_SERVICE_PORT || '3003'}/health`],
  ['platform /health', `http://127.0.0.1:${process.env.PLATFORM_SERVICE_PORT || '3004'}/health`],
];

function get(url) {
  return new Promise((resolve) => {
    const req = http.get(url, (res) => {
      res.resume();
      resolve({ ok: res.statusCode >= 200 && res.statusCode < 500, status: res.statusCode });
    });
    req.on('error', (e) => resolve({ ok: false, error: e.message }));
    req.setTimeout(4000, () => {
      req.destroy();
      resolve({ ok: false, error: 'timeout' });
    });
  });
}

(async () => {
  console.log('Checking local microservices (Flutter uses gateway port — default dev stack 3010)...\n');
  let bad = 0;
  for (const [name, url] of CHECKS) {
    const r = await get(url);
    const line = r.ok
      ? `OK  ${name} → ${url} (HTTP ${r.status})`
      : `FAIL ${name} → ${url} (${r.error || 'HTTP ' + r.status})`;
    console.log(line);
    if (!r.ok) bad += 1;
  }
  console.log('');
  if (bad > 0) {
    console.error(
      'Some services are down. Start the full stack:  cd backend && npm run dev:stack\n' +
        'Then Flutter:  flutter run -d chrome --dart-define=USE_LOCAL_API=true --dart-define=LOCAL_API_PORT=' +
        GW
    );
    process.exit(1);
  }
  console.log('All checks passed.');
})();
