/**
 * Quick check: gateway + 4 microservices (or detect monolith on 3000).
 * Usage: node scripts/check-local-microservices.js
 * Env: GATEWAY_PORT (default 3010), AUTH_SERVICE_PORT (3001), ...
 */
const http = require('http');

const GW = parseInt(process.env.GATEWAY_PORT || '3010', 10);
const MONOLITH = 3000;

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
  console.log('Checking local backend…');
  console.log(
    '(ECONNREFUSED = us port par koi server nahi chal raha — pehle backend start karo.)\n'
  );

  let bad = 0;
  for (const [name, url] of CHECKS) {
    const r = await get(url);
    const line = r.ok
      ? `OK  ${name} → ${url} (HTTP ${r.status})`
      : `FAIL ${name} → ${url} (${r.error || 'HTTP ' + r.status})`;
    console.log(line);
    if (!r.ok) bad += 1;
  }

  const mono = await get(`http://127.0.0.1:${MONOLITH}/health`);
  console.log(
    mono.ok
      ? `OK  monolith /health → http://127.0.0.1:${MONOLITH}/health (HTTP ${mono.status})`
      : `—  monolith /health → http://127.0.0.1:${MONOLITH}/health (${mono.error || 'down'})`
  );

  console.log('');

  if (bad === 0) {
    console.log('All microservices + gateway checks passed.');
    process.exit(0);
  }

  if (mono.ok) {
    console.log(
      '→ Monolith chal raha hai (:3000). Microservices stack band hai — ye normal hai.\n' +
        '   Flutter:  flutter run ... --dart-define=USE_LOCAL_API=true\n' +
        '   (LOCAL_API_PORT mat do — default 3000 monolith ke liye hai.)\n'
    );
    process.exit(0);
  }

  console.error(
    'Kuch bhi listen nahi kar raha. Ek option chuno:\n\n' +
      '  A) Sab microservices + gateway:  cd backend && npm run dev:stack\n' +
      `     phir Flutter: --dart-define=USE_LOCAL_API=true --dart-define=LOCAL_API_PORT=${GW}\n\n` +
      '  B) Sirf ek process (aasaan):       cd backend && node server.js\n' +
      '     phir Flutter: --dart-define=USE_LOCAL_API=true  (port 3000)\n'
  );
  process.exit(1);
})();
