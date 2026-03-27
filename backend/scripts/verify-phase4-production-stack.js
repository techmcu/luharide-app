/**
 * Phase 4 — after deploy: gateway + all upstream microservices healthy.
 * Uses HTTP (no curl). Run on VPS from backend/: npm run phase4:verify:stack
 *
 * Optional: VERIFY_GATEWAY_URL=http://127.0.0.1:3000
 */
const http = require('http');

const BASE = (process.env.VERIFY_GATEWAY_URL || 'http://127.0.0.1:3000').replace(/\/$/, '');

function fetchJson(path) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE);
    const req = http.request(
      url,
      { method: 'GET', timeout: 15000 },
      (res) => {
        let body = '';
        res.on('data', (c) => {
          body += c;
        });
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, json: JSON.parse(body) });
          } catch (e) {
            reject(new Error(`Invalid JSON for ${path}: ${body.slice(0, 200)}`));
          }
        });
      }
    );
    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`timeout ${path}`));
    });
    req.end();
  });
}

async function main() {
  const h = await fetchJson('/api/health');
  if (h.status !== 200 || !h.json.ok) {
    console.error('[phase4] FAIL /api/health', h.status, h.json);
    process.exit(1);
  }

  const u = await fetchJson('/api/health/upstreams');
  if (u.status !== 200 || !u.json.ok) {
    console.error('[phase4] FAIL /api/health/upstreams', u.status, u.json);
    process.exit(1);
  }

  const names = Object.keys(u.json.upstreams || {});
  const bad = names.filter((k) => !u.json.upstreams[k].ok);
  if (bad.length) {
    console.error('[phase4] FAIL upstreams:', bad.join(', '));
    process.exit(1);
  }

  console.log('[phase4] OK — gateway + upstreams:', names.join(', '));
}

main().catch((e) => {
  console.error('[phase4] FAIL', e.message);
  process.exit(1);
});
