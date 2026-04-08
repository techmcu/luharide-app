/**
 * Phase 4 — after deploy: gateway + all upstream microservices healthy.
 * Uses HTTP (no curl). Run on VPS from backend/: npm run phase4:verify:stack
 *
 * Optional: VERIFY_GATEWAY_URL=http://127.0.0.1:3000
 *
 * After PM2 reload, a service may take a few seconds to listen (short ECONNREFUSED window).
 * Retries upstream checks: PHASE4_UPSTREAM_ATTEMPTS (default 20), PHASE4_UPSTREAM_DELAY_MS (default 2500).
 */
const http = require('http');

const BASE = (process.env.VERIFY_GATEWAY_URL || 'http://127.0.0.1:3000').replace(/\/$/, '');
const UPSTREAM_ATTEMPTS = Math.max(1, parseInt(process.env.PHASE4_UPSTREAM_ATTEMPTS || '20', 10));
const UPSTREAM_DELAY_MS = Math.max(100, parseInt(process.env.PHASE4_UPSTREAM_DELAY_MS || '2500', 10));

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

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

  let u = { status: 0, json: {} };
  for (let attempt = 1; attempt <= UPSTREAM_ATTEMPTS; attempt++) {
    try {
      u = await fetchJson('/api/health/upstreams');
    } catch (e) {
      console.log(
        `[phase4] /api/health/upstreams request failed (${e.message}), attempt ${attempt}/${UPSTREAM_ATTEMPTS}`
      );
      if (attempt < UPSTREAM_ATTEMPTS) {
        await sleep(UPSTREAM_DELAY_MS);
        continue;
      }
      console.error('[phase4] FAIL — could not reach gateway upstream health', e.message);
      process.exit(1);
    }

    const names = Object.keys(u.json.upstreams || {});
    const bad = names.filter((k) => !u.json.upstreams[k].ok);

    if (u.status === 200 && u.json.ok && !bad.length) {
      console.log('[phase4] OK — gateway + upstreams:', names.join(', '));
      return;
    }

    const reason =
      u.status !== 200 || !u.json.ok
        ? `gateway health/upstreams status=${u.status} ok=${u.json?.ok}`
        : `unhealthy: ${bad.join(', ')}`;
    if (attempt < UPSTREAM_ATTEMPTS) {
      console.log(
        `[phase4] upstreams not ready (${reason}), retry ${attempt}/${UPSTREAM_ATTEMPTS} in ${UPSTREAM_DELAY_MS}ms…`
      );
      await sleep(UPSTREAM_DELAY_MS);
    }
  }

  console.error('[phase4] FAIL /api/health/upstreams', u.status, u.json);
  process.exit(1);
}

main().catch((e) => {
  console.error('[phase4] FAIL', e.message);
  process.exit(1);
});
